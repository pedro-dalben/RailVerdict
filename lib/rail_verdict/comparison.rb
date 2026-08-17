# frozen_string_literal: true

require "set"

module RailVerdict
  class Comparison
    Result = Struct.new(:existing, :introduced, :resolved, :changed, :moved, :counts, :classified_findings, :orphaned_waivers, keyword_init: true)

    def self.classify(findings:, baseline:, waivers: [], clock: Time.now.utc)
      findings = findings.sort_by(&:sort_key)
      if baseline.nil?
        introduced = findings.map { |finding| restate(finding, "introduced") }
        resolved = []
        existing = []
        changed = []
        moved = []
        return build_result(existing: existing, introduced: introduced, resolved: resolved, changed: changed, moved: moved, findings: findings, baseline: baseline, waivers: waivers, clock: clock)
      end

      baseline_fps = Set.new(baseline.entries.map { |entry| entry.fetch("fingerprint") })
      baseline_by_fp = baseline.entries.to_h { |entry| [entry.fetch("fingerprint"), entry] }
      current_by_fp = findings.to_h { |finding| [finding.fingerprint, finding] }
      current_fps = Set.new(current_by_fp.keys)

      existing_fps = baseline_fps & current_fps
      resolved_fps = baseline_fps - current_fps
      introduced_fps = current_fps - baseline_fps

      existing = existing_fps.map { |fingerprint| restate(current_by_fp.fetch(fingerprint), "existing") }.sort_by(&:sort_key)
      resolved_entries = resolved_fps.map { |fingerprint| baseline_by_fp.fetch(fingerprint) }.sort_by { |entry| entry.fetch("fingerprint") }
      introduced_candidates = introduced_fps.map { |fingerprint| current_by_fp.fetch(fingerprint) }.sort_by(&:sort_key)

      resolved_by_key = build_resolved_index(resolved_entries)
      changed, moved, introduced = partition_introduced(introduced_candidates, resolved_by_key, resolved_entries)
      resolved = resolved_entries.map { |entry| { "fingerprint" => entry.fetch("fingerprint"), "analyzer" => entry.fetch("analyzer"), "rule_id" => entry.fetch("rule_id"), "path" => entry.fetch("path"), "message" => entry.fetch("message"), "state" => "resolved" } }
      if changed.any? || moved.any?
        consumed_fps = Set.new((changed + moved).flat_map { |pair| [pair[:resolved].fetch("fingerprint")] })
        resolved = resolved.reject { |entry| consumed_fps.include?(entry.fetch("fingerprint")) }
      end

      all_grouped = { existing: existing, introduced: introduced, changed: changed.map { |pair| pair[:finding] }, moved: moved.map { |pair| pair[:finding] } }
      waived, orphaned = apply_waivers(all_grouped, findings, baseline, waivers, clock) if waivers.any?
      if waived
        introduced = introduced.reject { |finding| waived.include?(finding.fingerprint) }
        existing = existing.reject { |finding| waived.include?(finding.fingerprint) }
        changed_findings = changed.map { |pair| pair[:finding] }.reject { |finding| waived.include?(finding.fingerprint) }
        moved_findings = moved.map { |pair| pair[:finding] }.reject { |finding| waived.include?(finding.fingerprint) }
        changed = changed.select { |pair| changed_findings.include?(pair[:finding]) }
        moved = moved.select { |pair| moved_findings.include?(pair[:finding]) }
        waived_findings = waived.map { |fingerprint| current_by_fp.fetch(fingerprint) }.map { |finding| restate(finding, "waived") }.sort_by(&:sort_key)
        classified_extra = waived_findings
      else
        classified_extra = []
        orphaned = []
        changed_findings = changed.map { |pair| pair[:finding] }
        moved_findings = moved.map { |pair| pair[:finding] }
      end

      classified = (existing + introduced + changed_findings + moved_findings + classified_extra).sort_by(&:sort_key)
      build_result(existing: existing, introduced: introduced, resolved: resolved, changed: changed_findings, moved: moved_findings, classified_findings: classified, waived: classified_extra, orphaned_waivers: orphaned || [], baseline: baseline)
    end

    def self.build_result(existing:, introduced:, resolved:, changed:, moved:, classified_findings: nil, waived: [], orphaned_waivers: [], baseline: nil, findings: nil, waivers: nil, clock: nil)
      classified_findings ||= (existing + introduced + changed + moved + waived).sort_by { |finding| finding.is_a?(Hash) ? finding.fetch("fingerprint") : finding.sort_key }
      counts = {
        "introduced" => introduced.length,
        "existing" => existing.length,
        "resolved" => resolved.length,
        "changed" => changed.length,
        "moved" => moved.length,
        "waived" => waived.length
      }
      Result.new(existing: existing.freeze, introduced: introduced.freeze, resolved: resolved.freeze, changed: changed.freeze, moved: moved.freeze, counts: counts.freeze, classified_findings: classified_findings.freeze, orphaned_waivers: orphaned_waivers.freeze)
    end
    private_class_method :build_result

    def self.restate(finding, state)
      Finding.new(
        fingerprint: finding.fingerprint,
        origin: finding.origin,
        analyzer: finding.analyzer,
        rule_id: finding.rule_id,
        category: finding.category,
        severity: finding.severity,
        confidence: finding.confidence,
        state: state,
        evidence_ref: finding.evidence_ref,
        location: finding.location,
        message: finding.message
      )
    end
    private_class_method :restate

    def self.build_resolved_index(resolved_entries)
      index = Hash.new { |hash, key| hash[key] = [] }
      resolved_entries.each do |entry|
        key = [entry.fetch("analyzer"), entry.fetch("rule_id"), entry.fetch("message")]
        index[key] << entry
      end
      index
    end
    private_class_method :build_resolved_index

    def self.partition_introduced(candidates, resolved_by_key, resolved_entries)
      changed = []
      moved = []
      introduced = []
      consumed_resolved = Set.new
      candidates.each do |finding|
        key_exact = [finding.analyzer, finding.rule_id, finding.message]
        exact_matches = resolved_by_key[key_exact].reject { |entry| consumed_resolved.include?(entry.fetch("fingerprint")) }
        if exact_matches.length == 1
          resolved_entry = exact_matches.first
          if resolved_entry.fetch("path") != finding.location.fetch("path")
            moved << { finding: restate(finding, "moved"), resolved: resolved_entry }
            consumed_resolved.add(resolved_entry.fetch("fingerprint"))
            next
          end
        end
        same_path_key = resolved_entries.select { |entry| entry.fetch("path") == finding.location.fetch("path") && entry.fetch("analyzer") == finding.analyzer && entry.fetch("rule_id") == finding.rule_id }
        same_path_unconsumed = same_path_key.reject { |entry| consumed_resolved.include?(entry.fetch("fingerprint")) }
        if same_path_unconsumed.length == 1 && same_path_unconsumed.first.fetch("message") != finding.message
          resolved_entry = same_path_unconsumed.first
          changed << { finding: restate(finding, "changed"), resolved: resolved_entry }
          consumed_resolved.add(resolved_entry.fetch("fingerprint"))
          next
        end
        introduced << restate(finding, "introduced")
      end
      [changed, moved, introduced]
    end
    private_class_method :partition_introduced

    def self.apply_waivers(grouped, findings, baseline, waivers, clock)
      current_fps = Set.new(findings.map(&:fingerprint))
      baseline_fps = baseline ? Set.new(baseline.entries.map { |entry| entry.fetch("fingerprint") }) : Set.new
      all_fps = current_fps | baseline_fps
      active = Set.new
      orphaned = []
      waivers.each do |waiver|
        hash = waiver.is_a?(Hash) ? waiver : waiver.to_h
        fingerprint = hash["fingerprint"] || hash[:fingerprint]
        next unless fingerprint

        if !all_fps.include?(fingerprint)
          orphaned << hash
          next
        end
        active.add(fingerprint) if waiver_active?(hash, clock)
      end
      [active, orphaned]
    end
    private_class_method :apply_waivers

    def self.waiver_active?(waiver, clock)
      created_at = parse_time(waiver["created_at"] || waiver[:created_at])
      expires_at = parse_time(waiver["expires_at"] || waiver[:expires_at])
      return false unless created_at && expires_at

      clock >= created_at && clock < expires_at
    end
    private_class_method :waiver_active?

    def self.parse_time(value)
      return nil if value.nil?

      Time.iso8601(value.to_s).utc
    rescue ArgumentError
      nil
    end
    private_class_method :parse_time
  end
end

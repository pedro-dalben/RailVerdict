# RailVerdict Lab

Run the synthetic external-consumer PR Intelligence scenarios with:

```sh
ruby -Ilib lab/pr_intelligence.rb
```

The script creates disposable Rails-shaped repositories and exercises the public `railverdict pr` command for a deterministic route signal, controlled introduced/resolved quality delta, and required incomplete analyzer evidence. It contains no private consumer data.

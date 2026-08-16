# frozen_string_literal: true

class User
  def initialize(name)
    @name = name
  end

  attr_reader :name
end

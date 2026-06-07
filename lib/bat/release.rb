module Bat
  class Release
    attr_reader :name, :path

    def self.from_path(path)
      Release.new('bat', [], path)
    end

    def initialize(name, versions, path = nil)
      @name = name
      @versions = versions
      @path = path
    end

    def ==(other)
      other.is_a?(Release) && other.name == name
    end

    def to_s
      name
    end
  end
end

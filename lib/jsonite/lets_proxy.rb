class Jsonite
  class LetsProxy < BasicObject

    undef_method :==, :!, :!=

    def initialize object, context, lets = {}
      @__object__, @__context__, @__lets__ = object, context, lets

      @__memoized__ = ::Hash.new do |memoized, name|
        memoized[name] = instance_exec @__context__, &@__lets__.fetch(name)
      end
    end

    def method_missing name, *args, &block
      if @__lets__.key?(name.to_s)
        @__memoized__[name.to_s]
      else
        @__object__.__send__ name, *args, &block
      end
    end

  end
end

class Jsonite
  class LetsProxy < BasicObject

    undef_method :==, :!, :!=

    def initialize object, context, lets = {}
      @__object, @__context, @__lets = object, context, lets

      @__memoized = ::Hash.new do |memoized, name|
        memoized[name] = instance_exec @__context, &@__lets.fetch(name)
      end
    end

    def method_missing name, *args, &block
      if @__lets.key?(name.to_s)
        @__memoized[name.to_s]
      else
        @__object.__send__ name, *args, &block
      end
    end

  end
end

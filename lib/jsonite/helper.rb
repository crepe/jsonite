require 'active_support/inflector'

class Jsonite

  module Helper
    module_function

    def resource_name resource
      if resource.respond_to?(:model_name) && resource.respond_to?(:to_ary)
        resource.model_name.collection
      elsif resource.class.respond_to? :model_name
        resource.class.model_name.singular
      end
    end

  end

end

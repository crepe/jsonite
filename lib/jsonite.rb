require 'jsonite/helper'

# A simple JSON presenter for hypermedia applications.
# Loosely adheers to HAL: http://stateless.co/hal_specification.html

class Jsonite

  class << self

    def present resource, options = {}
      presenter = options.fetch :with, self

      case resource
      when Jsonite
        resource.as_json options
      else
        resource = if resource.respond_to?(:to_ary)
          resource.to_ary.map do |r|
            present presenter.new(r), options.merge(root: nil)
          end
        elsif resource.respond_to?(:as_json)
          present presenter.new(resource), options.merge(root: nil)
        else
          resource
        end

        root = options.fetch :root, Helper.resource_name(resource)
        root ? { root => resource } : resource
      end
    end

    def property name, options = {}, &handler
      properties[name] = handler || proc { send name }
    end

    def properties *properties
      @properties ||= {}
      properties.map(&method(:property)) if properties.present?
      @properties
    end

    def embedded name, options = {}, &handler
      unless options[:with].is_a?(Class) && options[:with] <= Jsonite
        raise KeyError, ':with option must be a Jsonite'
      end

      property name, options do |context|
        options = { context: context, root: nil }.merge(options)
        resource = handler ? instance_exec(context, &handler) : send(name)
        Jsonite.present resource, options
      end
    end

    def link rel = :self, options = {}, &handler
      links[rel] = options.merge handler: handler
    end

    def links
      @links ||= {}
    end

    def inherited presenter
      presenter.properties.update properties
      presenter.links.update links
    end

  end

  attr_reader :resource, :defaults

  def initialize resource, defaults = {}
    @resource, @defaults = resource, defaults
  end

  def as_json options = {}
    return resource.as_json options if instance_of? Jsonite
    context, options = options.delete(:context), defaults.merge(options)
    properties(context).merge(_links: links(context)).as_json options
  end

  def properties context = nil
    context ||= resource
    self.class.properties.each_with_object({}) do |(name, handler), props|
      catch :ignore do
        props[name] = resource.instance_exec context, &handler
      end
    end
  end

  def links context = nil
    context ||= resource
    self.class.links.each_with_object({}) do |(name, link), props|
      catch :ignore do
        href = resource.instance_exec context, &link[:handler]
        props[name] = { href: href }.merge link.except :handler
      end
    end
  end

end

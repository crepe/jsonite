require 'active_support/core_ext/object/blank'
require 'active_support/json/encoding'
require 'jsonite/helper'

# A tiny, HAL-compliant JSON presenter.
#
# http://tools.ietf.org/html/draft-kelly-json-hal-05
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
      handler ||= if options[:with]
        proc { Jsonite.present send(name), with: options[:with] }
      else
        proc { send name }
      end

      properties[name] = handler
    end

    def properties *properties
      @properties ||= {}
      properties.map(&method(:property)) if properties.present?
      @properties
    end

    def link rel = :self, options = {}, &handler
      links[rel] = options.merge handler: Proc.new # enforce handler presence
    end

    def links
      @links ||= {}
    end

    def embed rel, options = {}, &handler
      if handler.nil?
        presenter = options.fetch :with
        handler = proc do |context|
          Jsonite.present send(rel), with: presenter, context: context
        end
      end

      embedded[rel] = handler
    end

    def embedded
      @embedded ||= {}
    end

    def inherited presenter
      presenter.properties.update properties
      presenter.links.update links
      presenter.embedded.update embedded
    end

  end

  attr_reader :resource, :defaults

  def initialize resource, defaults = {}
    @resource, @defaults = resource, defaults
  end

  def as_json options = {}
    return resource.as_json options if instance_of? Jsonite
    options = defaults.merge options
    context = options.delete :context
    hash = properties context
    hash.update _links: links(context) if self.class.links.present?
    hash.update _embedded: embedded(context) if self.class.embedded.present?
    hash.as_json options
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
    self.class.links.each_with_object({}) do |(rel, link), links|
      catch :ignore do
        href = resource.instance_exec context, &link[:handler]
        links[rel] = { href: href }.merge link.except :handler
      end
    end
  end

  def embedded context = nil
    context ||= resource
    self.class.embedded.each_with_object({}) do |(name, handler), embedded|
      catch :ignore do
        embedded[name] = resource.instance_exec context, &handler
      end
    end
  end

end

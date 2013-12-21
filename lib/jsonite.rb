require 'active_support/core_ext/object/blank'
require 'active_support/json/encoding'
require 'jsonite/helper'

# = Jsonite
#
# A tiny, HAL-compliant JSON presenter.
#
# http://tools.ietf.org/html/draft-kelly-json-hal-05
class Jsonite

  class << self

    # Presents a resource (or array of resources).
    #
    #   class UserPresenter < Jsonite
    #     property :email
    #   end
    #   users = User.all
    #   UserPresenter.present(users.first)
    #   # => {"email"=>"stephen@example.com"}
    #   UserPresenter.present(users)
    #   # => [{"email"=>"stephen@example.com"}, ...]
    #
    # Configuration options:
    # * <tt>:root</tt> - A root key to wrap the resource with.
    # * <tt>:with</tt> - A specified presenter (defaults to `self`).
    #
    # All other options are passed along to <tt>#present</tt>.
    def present resource, options = {}
      presenter = options.delete(:with) { self }

      presented = if resource.is_a? Jsonite
        resource.present options
      elsif resource.respond_to?(:to_ary)
        resource = resource.to_ary.map do |member|
          presenter.new(member).present options.merge root: nil
        end
      else
        presenter.new(resource).present options.merge root: nil
      end

      root = options.fetch(:root) { Helper.resource_name(resource) }
      root ? { root => presented } : presented
    end

    # Defines a property to be exposed during presentation.
    #
    #   class UserPresenter < Jsonite
    #     property :email
    #   end
    #   # {
    #   #   "email": "stephen@example.com"
    #   # }
    #
    # Configuration options:
    # * <tt>:with</tt> - A specified presenter. Ignored when a handler is
    #   present. Useful when you want to embed a resource as a property (rather
    #   than in the <tt>_embedded</tt> node).
    def property name, options = {}, &handler
      handler ||= if options[:with]
        proc { options[:with].present send(name), root: nil }
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

    # Defines a link.
    #
    #   class UserPresenter < Jsonite
    #     link do |context|
    #       context.user_url self
    #     end
    #     link :todos do |context|
    #       context.user_todos_url self
    #     end
    #   end
    #   # {
    #   #   "_links": {
    #   #     "self": {
    #   #       "href": "http://example.com/users/8oljbpyjetu8"
    #   #     },
    #   #     "todos": {
    #   #       "href": "http://example.com/users/8oljbpyjetu8/todos"
    #   #     }
    #   #   }
    #   # }
    #
    # Configuration options are displayed as additional properties on a link.
    #
    #   class UserPresenter < Jsonite
    #     link :todos, title: 'To-dos', templated: true do |context|
    #       "#{context.user_todos_url self}{?done}"
    #     end
    #   end
    #   # {
    #   #   "_links": {
    #   #     "todos": {
    #   #       "href": "http://example.com/users/8oljbpyjetu8/todos{?done}",
    #   #       "title": "To-dos",
    #   #       "templated": true
    #   #     }
    #   #   }
    #   # }
    def link rel = :self, options = {}, &handler
      links[rel] = options.merge handler: Proc.new # enforce handler presence
    end

    def links
      @links ||= {}
    end

    # Defines an embedded resource.
    #
    #   class TodoPresenter < Jsonite
    #     property :description
    #   end
    #   class UserPresenter < Jsonite
    #     embed :todos, with: TodoPresenter
    #   end
    #   # {
    #   #   "_embedded": {
    #   #     "todos": [
    #   #       {
    #   #         "description": "Buy milk"
    #   #       }
    #   #     ]
    #   #   }
    #   # }
    #
    # Configuration options:
    # * <tt>:with</tt> - A specified presenter. Required if a handler isn't
    #   present.
    def embed rel, options = {}, &handler
      if handler.nil?
        presenter = options.fetch :with
        handler = proc do |context|
          presenter.present send(rel), context: context, root: nil
        end
      end

      embedded[rel] = handler
    end

    def embedded
      @embedded ||= {}
    end

    private

    def inherited presenter
      presenter.properties.update properties
      presenter.links.update links
      presenter.embedded.update embedded
    end

  end

  attr_reader :resource, :defaults

  # Initializes a new presenter instance with the given resource.
  #
  # Default options are passed to #as_json during presentation.
  def initialize resource, defaults = {}
    @resource, @defaults = resource, defaults
  end

  # Returns a raw representation (Hash) of the resource.
  #
  # Options:
  # * <tt>:context</tt> - A context to pass a presenter instance while
  #   rendering properties, links, and embedded resources.
  def present options = {}
    options = defaults.merge options

    context = options.delete :context
    presented = properties(context)
    presented['_links'] = links(context) if self.class.links.present?
    presented['_embedded'] = embedded(context) if self.class.embedded.present?

    root = options.fetch(:root) { Helper.resource_name(resource) }
    root ? { root => presented } : presented
  end

  # Returns a JSON-ready representation (Hash) of the resource.
  #
  # Options:
  # * <tt>:root</tt>
  def as_json options = {}
    present(options).as_json options
  end

  private

  def properties context = nil
    self.class.properties.each_with_object({}) do |(name, handler), props|
      catch :ignore do
        props[name.to_s] = resource.instance_exec context, &handler
      end
    end
  end

  def links context = nil
    self.class.links.each_with_object({}) do |(rel, link), links|
      catch :ignore do
        href = resource.instance_exec context, &link[:handler]
        links[rel.to_s] = { 'href' => href }.merge link.except :handler
      end
    end
  end

  def embedded context = nil
    self.class.embedded.each_with_object({}) do |(name, handler), embedded|
      catch :ignore do
        embedded[name.to_s] = resource.instance_exec context, &handler
      end
    end
  end

end

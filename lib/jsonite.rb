require 'active_support/core_ext/object/blank'
require 'active_support/json/encoding'
require 'jsonite/helper'
require 'jsonite/lets_proxy'

# = Jsonite
#
# A tiny, HAL-compliant JSON presenter.
#
# http://tools.ietf.org/html/draft-kelly-json-hal-05
class Jsonite

  @@mapping = Hash.new do |mapping, key|
    if ancestor = key.ancestors.find { |a| mapping.key? a }
      mapping[key] = mapping[ancestor]
    end
  end

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
    def present resource, **options
      presented = if resource.is_a? Jsonite
        resource.present options
      elsif resource.respond_to? :to_ary
        resource.to_ary.map do |member|
          present member, options.merge(root: nil)
        end
      else
        presenter = options.fetch :with do
          self == Jsonite and @@mapping[resource.class] or self
        end
        presenter.new(resource).present options.merge root: nil
      end

      root = options.fetch(:root) { Helper.resource_name resource }
      root ? { root => presented } : presented
    end

    # Sets a default presenter for a given resource class.
    #
    #   class UserPresenter < Jsonite
    #     presents User
    #     property :email
    #   end
    #   Jsonite.present(User.first)
    #   # => {"email"=>"stephen@example.com"}
    def presents resource_class
      @@mapping[resource_class] = self
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
    # * <tt>:ignore_nil</tt> - Ignore `nil`.
    def property name, type = nil, **options, &handler
      properties[name.to_s] = { type: type, handler: handler }.merge options
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
      links[rel.to_s] = { handler: Proc.new }.merge options # require handler
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
    # * <tt>:ignore_nil</tt> - Ignore `nil`.
    def embed rel, **options, &handler
      options.fetch :with unless handler
      embedded[rel.to_s] = { handler: handler }.merge options
    end

    def embedded
      @embedded ||= {}
    end

    # Defines a memoized "virtual" method on the resource.
    #
    #   class UserPresenter < Jsonite
    #     let(:full_name) { "#{first_name} #{last_name}" }
    #     property :full_name
    #   end
    #   # {
    #   #   "full_name": "Stephen Celis"
    #   # }
    def let name, &handler
      lets[name.to_s] = handler
    end

    def lets
      @lets ||= {}
    end

    private

    def inherited subclass
      if name.nil? and resource_class = @@mapping.invert[self]
        subclass.presents resource_class
      end

      subclass.properties.update properties
      subclass.links.update links
      subclass.embedded.update embedded
      subclass.lets.update lets
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
    proxied = proxied_resource context

    presented = properties proxied, context
    _links = links proxied, context
    presented['_links'] = _links if _links.present?
    _embedded = embedded proxied, context
    presented['_embedded'] = _embedded if _embedded.present?

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

  def proxied_resource context = nil
    lets = self.class.lets
    lets.any? ? LetsProxy.new(resource, context, lets) : resource
  end

  def properties object, context = nil
    self.class.properties.each_with_object({}) do |(name, options), props|
      catch(:ignore) { props[name] = fetch name, object, context, options }
    end
  end

  def links object, context = nil
    self.class.links.each_with_object({}) do |(rel, link), links|
      catch :ignore do
        href = fetch rel, object, context, link
        links[rel] = { 'href' => href }.merge link.except :handler
      end
    end
  end

  def embedded object, context = nil
    self.class.embedded.each_with_object({}) do |(name, options), embeds|
      catch(:ignore) { embeds[name] = fetch name, object, context, options }
    end
  end

  def fetch name, object, context, options
    value = if options[:handler]
      object.instance_exec context, &options[:handler]
    else
      object.__send__ name
    end

    throw :ignore if options[:ignore_nil] && value.nil?

    if options[:with] && !value.nil?
      return options[:with].present value, context: context, root: nil
    end

    value
  end

end

def Jsonite resource_class
  Class.new(Jsonite).tap { |presenter| presenter.presents resource_class }
end

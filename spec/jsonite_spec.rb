require 'jsonite'
require 'ostruct'

describe Jsonite do

  describe ".present" do

    context "a hash" do

      let :resource do
        {:name=>"Stephen"}
      end

      it "passes through unmodified" do
        presented = Jsonite.present resource
        expect(presented).to eq resource
      end

    end

    context "a registered resource" do

      let :presenter do
        Class.new Jsonite do
          property :name
        end
      end

      let :resource do
        OpenStruct.new name: 'Stephen'
      end

      it "presents a single resource" do
        presented = Jsonite.present resource, with: presenter
        expect(presented).to eq :name=>"Stephen"
      end

      it "presents an array of resources" do
        presented = Jsonite.present [resource, resource], with: presenter
        expect(presented).to eq [{:name=>"Stephen"}, {:name=>"Stephen"}]
      end

      it "defaults to using itself as presenter class" do
        presented = presenter.present resource
        expect(presented).to eq :name=>"Stephen"
      end

    end

  end

  describe ":root" do
    let :model do
      Class.new do
        include ActiveModel::Model
        attr_accessor :name

        def self.name
          'User'
        end
      end
    end

    let :resource do
      model.new name: 'Stephen'
    end

    let :relation do
      [resource, resource].tap do |relation|
        class << relation
          def model_name() first.model_name end
          def to_ary() self end
        end
      end
    end

    let :presenter do
      Class.new Jsonite do
        property :name
      end
    end

    it "presents a singular resource with a singular root" do
      presented = presenter.present resource
      expect(presented).to eq "user"=>{"name"=>"Stephen"}
    end

    it "presents a collection with a plural root" do
      presented = presenter.present relation
      expect(presented).to eq "users"=>[{"name"=>"Stephen"},{"name"=>"Stephen"}]
    end
  end

  describe ".presents" do

    let! :presenter do
      Class.new(Jsonite(resource_class)) do
        property :name
      end
    end

    let :resource_class do
      Class.new OpenStruct
    end

    let :resource do
      resource_class.new name: 'Stephen', age: 30
    end

    it "sets a default presenter for a given resource class" do
      presented = Jsonite.present resource
      expect(presented).to eq :name=>"Stephen"

      presented = Jsonite.present [resource, resource]
      expect(presented).to eq [{:name=>"Stephen"}, {:name=>"Stephen"}]
    end

    it "presents resource subclasses" do
      subclass = Class.new resource_class
      presented = Jsonite.present subclass.new name: 'Stephen', age: 30
      expect(presented).to eq :name=>"Stephen"
    end

  end

  describe ".resource_class" do

    let! :presenter do
      Class.new(Jsonite(resource_class)) do
        property :name
      end
    end

    let :resource_class do
      Class.new OpenStruct
    end

    let :resource do
      resource_class.new name: 'Stephen', age: 30
    end

    it "exposes the registered resource class for a given presenter" do
      expect(presenter.resource_class).to eq resource_class
    end

    it "returns nil for a presenter without registered resource class" do
      expect(Jsonite.resource_class).to be_nil
    end

  end

  describe ".property" do

    it "exposes a specified attribute when presenting an object" do
      presenter = Class.new Jsonite do
        property :name
      end
      presented = presenter.new OpenStruct.new name: 'Stephen'
      json = presented.to_json
      expect(json).to eq '{"name":"Stephen"}'
    end

    it "evaluates a property block in the context of the presented object" do
      presenter = Class.new Jsonite do
        property :screamed_name do
          name.upcase
        end
      end
      presented = presenter.new OpenStruct.new name: 'Stephen'
      json = presented.to_json
      expect(json).to eq '{"screamed_name":"STEPHEN"}'
    end

    it "can pass an additional context to the property block" do
      presenter = Class.new Jsonite do
        property :screamed_name do |helper|
          helper.scream name
        end
      end
      context = Module.new do
        module_function
        def scream string
          string.upcase
        end
      end
      resource = OpenStruct.new name: 'Stephen'
      presented = presenter.new resource, context: context
      json = presented.to_json
      expect(json).to eq '{"screamed_name":"STEPHEN"}'
    end

    it "ignores nil properties with ignore_nil: true" do
      presenter = Class.new Jsonite do
        property :name, ignore_nil: true
      end
      presented = presenter.new OpenStruct.new
      json = presented.to_json
      expect(json).to eq '{}'
    end

    it "ignores properties that throw :ignore" do
      presenter = Class.new Jsonite do
        property(:name) { name || throw(:ignore) }
      end
      presented = presenter.new OpenStruct.new
      json = presented.to_json
      expect(json).to eq '{}'
    end

    it "presents with a presenter using the :with option" do
      todo_presenter = Class.new Jsonite do
        property :description
      end
      user_presenter = Class.new Jsonite do
        property :todos, with: todo_presenter
      end
      user = OpenStruct.new todos: [OpenStruct.new(description: 'Buy milk')]
      presented_user = user_presenter.new user
      json = presented_user.to_json
      expect(json).to eq(
        '{"todos":[{"description":"Buy milk"}]}'
      )
    end

  end

  describe ".link" do

    it "renders a link from a given block" do
      presenter = Class.new Jsonite do
        link :todos do
          '/todos'
        end
      end
      presented = presenter.new :root
      json = presented.to_json
      expect(json).to eq '{"_links":{"todos":{"href":"/todos"}}}'
    end

    it "evaulates a link block in the context of the presented object" do
      presenter = Class.new Jsonite do
        link :todos do
          "/users/#{id}/todos"
        end
      end
      presented = presenter.new OpenStruct.new id: 1
      json = presented.to_json
      expect(json).to eq '{"_links":{"todos":{"href":"/users/1/todos"}}}'
    end

    it "links to 'self' when not otherwise specified" do
      presenter = Class.new Jsonite do
        link { "/users/#{id}" }
      end
      presented = presenter.new OpenStruct.new id: 1
      json = presented.to_json
      expect(json).to eq '{"_links":{"self":{"href":"/users/1"}}}'
    end

    it "can pass an additional context to the link block" do
      presenter = Class.new Jsonite do
        link :self do |context|
          context.url_for :users, id
        end
      end
      context = Module.new do
        module_function
        def url_for *args
          "https://example.com/#{args.join '/'}"
        end
      end
      presented = presenter.new OpenStruct.new(id: 1), context: context
      json = presented.to_json
      expect(json).to eq(
        '{"_links":{"self":{"href":"https://example.com/users/1"}}}'
      )
    end

    it "can specify link properties" do
      presenter = Class.new Jsonite do
        link :todos, templated: true do
          "/users/#{id}/todos{?done}"
        end
      end
      presented = presenter.new OpenStruct.new id: 1
      json = presented.to_json
      expect(json).to eq(
        '{"_links":{"todos":{"href":"/users/1/todos{?done}","templated":true}}}'
      )
    end

  end

  describe ".embed" do

    it "exposes a specified relationship when presenting an object" do
      todo_presenter = Class.new Jsonite do
        property :description
      end
      user_presenter = Class.new Jsonite do
        embed :todos, with: todo_presenter
      end
      user = OpenStruct.new todos: [OpenStruct.new(description: 'Buy milk')]
      presented_user = user_presenter.new user
      json = presented_user.to_json
      expect(json).to eq(
        '{"_embedded":{"todos":[{"description":"Buy milk"}]}}'
      )
    end

    it "requires :with option without an embed block" do
      expect {
        Class.new Jsonite do
          embed :todos
        end
      }.to raise_exception KeyError
    end

    it "evaluates an embed block in the context of the presented object" do
      todo_presenter = Class.new Jsonite do
        property :description
      end
      user_presenter = Class.new Jsonite do
        embed :todos do
          Jsonite.present todos, with: todo_presenter
        end
      end
      user = OpenStruct.new todos: [OpenStruct.new(description: 'Buy milk')]
      presented_user = user_presenter.new user
      json = presented_user.to_json
      expect(json).to eq(
        '{"_embedded":{"todos":[{"description":"Buy milk"}]}}'
      )
    end

    it "automatically passes contexts through" do
      todo_presenter = Class.new Jsonite do
        property :description do |context|
          context.scream description
        end
      end
      user_presenter = Class.new Jsonite do
        embed :todos, with: todo_presenter
      end
      context = Module.new do
        module_function
        def scream string
          string.upcase
        end
      end
      user = OpenStruct.new todos: [OpenStruct.new(description: 'Buy milk')]
      presented_user = user_presenter.new user, context: context
      json = presented_user.to_json
      expect(json).to eq(
        '{"_embedded":{"todos":[{"description":"BUY MILK"}]}}'
      )
    end

    it "can pass an additional context to the embed block" do
      todo_presenter = Class.new Jsonite do
        property :description do |context|
          context.scream description
        end
      end
      user_presenter = Class.new Jsonite do
        embed :todos do |context|
          Jsonite.present todos, with: todo_presenter, context: context
        end
      end
      context = Module.new do
        module_function
        def scream string
          string.upcase
        end
      end
      user = OpenStruct.new todos: [OpenStruct.new(description: 'Buy milk')]
      presented_user = user_presenter.new user, context: context
      json = presented_user.to_json
      expect(json).to eq(
        '{"_embedded":{"todos":[{"description":"BUY MILK"}]}}'
      )
    end

    it "ignores nil embeds when ignore_nil: true" do
      user_presenter = Class.new Jsonite
      user_presenter.embed :best_friend, with: user_presenter, ignore_nil: true
      user = OpenStruct.new
      presented_user = user_presenter.present user
      json = presented_user.to_json
      expect(json).to eq '{}'
    end

    it "allows nil embeds" do
      user_presenter = Class.new Jsonite
      user_presenter.embed :best_friend, with: user_presenter
      user = OpenStruct.new
      presented_user = user_presenter.present user
      json = presented_user.to_json
      expect(json).to eq '{"_embedded":{"best_friend":null}}'
    end

  end

  describe ".let" do

    it "defines a virtual resource method" do
      user_presenter = Class.new Jsonite
      user_presenter.let(:full_name) { "#{first_name} #{last_name}" }
      user_presenter.property(:full_name)
      user = OpenStruct.new first_name: "John", last_name: "Doe"
      presented_user = user_presenter.present user
      json = presented_user.to_json
      expect(json).to eq '{"full_name":"John Doe"}'
    end

    it "provides the context as a block argument" do
      user_presenter = Class.new Jsonite
      user_presenter.let(:user_agent) { |ctx| ctx.user_agent }
      user_presenter.property(:user_agent)
      user = OpenStruct.new
      ctx = OpenStruct.new(user_agent: "curl")
      presented_user = user_presenter.present user, context: ctx
      json = presented_user.to_json
      expect(json).to eq '{"user_agent":"curl"}'
    end

    it "allows other lets to be called" do
      user_presenter = Class.new Jsonite
      user_presenter.let(:first_name) { "John" }
      user_presenter.let(:last_name) { "Doe" }
      user_presenter.let(:full_name) { "#{first_name} #{last_name}" }
      user_presenter.property(:full_name)
      user = OpenStruct.new
      presented_user = user_presenter.present user
      json = presented_user.to_json
      expect(json).to eq '{"full_name":"John Doe"}'
    end

  end
end

require 'jsonite'
require 'ostruct'

describe Jsonite do

  describe ".property" do

    it "exposes a specified property when presenting an object" do
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
      presented = presenter.new OpenStruct.new name: 'Stephen'
      json = presented.to_json context: context
      expect(json).to eq '{"screamed_name":"STEPHEN"}'
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
        link { |context| context.url_for :users, id }
      end
      context = Module.new do
        module_function
        def url_for *args
          "https://example.com/#{args.join '/'}"
        end
      end
      presented = presenter.new OpenStruct.new id: 1
      json = presented.to_json context: context
      expect(json).to eq(
        '{"_links":{"self":{"href":"https://example.com/users/1"}}}'
      )
    end

  end

end

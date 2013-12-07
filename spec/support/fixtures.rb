require 'active_model'
require 'jsonite'

Document = Struct.new(:name, :path, :content_type, :related_documents) do
  def self.model_name
    @_model_name ||= ActiveModel::Name.new self
  end
end

class DocumentPresenter < Jsonite
  property :name
  property :path
  property :content_type
  property(:updated_at) { Time.at 1381734000 }
  property(:created_at) { Time.at 1381834000 }

  class RelatedDocumentPresenter < self; end

  property :related_documents, with: RelatedDocumentPresenter
end

User = Struct.new(:name, :age, :friends, :documents) do
  def self.model_name
    @_model_name ||= ActiveModel::Name.new self
  end
end

class UserPresenter < Jsonite
  property :name
  property :age
  property(:location) { '37.788079, -122.401288' }
  property(:updated_at) { Time.at 1381734000 }
  property(:created_at) { Time.at 1381834000 }

  property :friends, with: self
  property :documents, with: DocumentPresenter
end

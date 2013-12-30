require 'benchmark'
require 'jsonite'
require_relative 'support/fixtures'

describe 'Jsonite performance' do

  let(:documents) do
    documents = 10.times.map do |i|
      Document.new "Document #{i}", "/documents/#{i}", 'text/html', []
    end

    documents.size.times do |i|
      documents[i].related_documents << documents[-i]
    end

    documents
  end

  # create a total of 175 nested objects (15 users, 160 documents)
  let(:users) do
    [
      user1 = User.new('David', 26, [], documents.slice(0..5)),
      user2 = User.new('Julie', 29, [ user1 ], documents.slice(3..8)),
      user3 = User.new('Thomas', 28, [ user1, user2 ], documents.slice(6..9)),
      User.new('Alfred', 24, [ user1, user2, user3 ], [])
    ]
  end

  it 'presents hundreds of objects very quickly' do
    time = Benchmark.realtime do |x|
      # 175 * 10 times = 1750 total presentations
      10.times { UserPresenter.present(users).as_json }
    end

    time.should < 0.2
  end

end

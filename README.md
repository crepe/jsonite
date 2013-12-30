# Jsonite [![Build Status][1]][2]

A tiny, [HAL-compliant][3] JSON presenter.

[1]: https://travis-ci.org/barrelage/jsonite.png
[2]: https://travis-ci.org/barrelage/jsonite
[3]: http://tools.ietf.org/html/draft-kelly-json-hal-05

## Install

``` rb
# Gemfile
gem 'jsonite'
```

## Example

``` rb
# todo_presenter.rb
class TodoPresenter < Jsonite
  property :description
end
```

``` rb
# user_presenter.rb
require 'todo_presenter'

class UserPresenter < Jsonite
  property :id
  property :email

  embed :todos, with: TodoPresenter

  link do |context|
    context.user_url self
  end
end
```

``` rb
# users_presenter.rb
require 'user_presenter'

class UsersPresenter < Jsonite
  property :count

  embed :users, with: UserPresenter do |context|
    self
  end
end
```

``` rb
# users_controller.rb
require 'users_presenter'
require 'user_presenter'

class UsersController < ApplicationController
  def index
    users = User.all
    render json: UsersPresenter.new(users, context: self)
  end
  # {
  #   "count": 12,
  #   "_embedded": {
  #     "users": [
  #       {
  #         ...
  #       }
  #     ]
  #   }
  # }

  def show
    user = User.find params[:id]
    render json: UserPresenter.new(user, context: self)
  end
  # {
  #   "id": "8oljbpyjetu8",
  #   "email": "stephen@example.com",
  #   "_embedded": {
  #     "todos": [
  #       {
  #         "description": "Buy milk"
  #       }
  #     ]
  #   },
  #   "_links": {
  #     "self":{
  #       "href": "http://example.com/users/8oljbpyjetu8"
  #     }
  #   }
  # }
end
```

## License

(The MIT License)

© 2013 Stephen Celis <stephen@stephencelis.com>, Evan Owen <kainosnoema@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

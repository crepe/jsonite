# Jsonite

Tiny JSON presenter.

## Install

``` rb
# Gemfile
gem 'jsonite'
```

## Examples

``` rb
require 'jsonite'

class UserPresenter < Jsonite
  property :id
  property :email

  embedded :todos, with: TodoPresenter

  link do |context|
    context.url_for :users, self
  end
end

def TodoPresenter < Jsonite
  description :name
end

class UsersController < ApplicationController
  def show
    user = User.find params[:id]
    render json: UserPresenter.new(user, context: self)
  end

  #  {
  #    "id": "8oljbpyjetu8"
  #    "email": "stephen@example.com",
  #    "todos": [
  #      {
  #        "description": "Buy milk"
  #      }
  #    ],
  #    "_links": {
  #      "self":{
  #        "href": "http://example.com/users/8oljbpyjetu8"
  #      }
  #    }
  #  }
end
```
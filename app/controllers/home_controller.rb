class HomeController < ApplicationController
  def index
    render json: { message: 'Welcome to Regulation System API', status: 'ok' }
  end
end

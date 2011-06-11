require 'rubygems'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'dm-core'
require 'dm-migrations'
require 'dm-timestamps'
require 'dm-validations'
require 'dm-serializer'
require 'dm-types'

###### Model 

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/database.sqlite3")

class Taxi
  include DataMapper::Resource
  property  :id,              Serial
  property  :first_name,      String,     :length => 100
  property  :last_name,       String,     :length => 100
  property  :license_plates,  String,     :key => true
  property  :password,        BCryptHash, :required => true 
  property  :account_balance, Integer
  property  :score,           Integer
  property  :latitude,        Float
  property  :longitude,       Float
end

class Trip
  include DataMapper::Resource
  property  :id,              String,   :key => true,  :default => lambda { |r, p| uuid }
  property  :latitude,        Float
  property  :longitude,       Float
  property  :destination,     String
  property  :created_at,      DateTime
  
  has 1,  :taxi
  has 1,  :passenger
end

class Passenger
  include DataMapper::Resource
  property  :id,              Serial
  property  :first_name,      String,       :length =>  100
  property  :last_name,       String,       :length =>  100
  property  :mobile_phone,    String
end

class Position
  include DataMapper::Resource
  property  :id,              Serial
  property  :latitude,        Float
  property  :longitude,       Float
  property  :created_at,      DateTime
  
  has 1, :taxi
end

DataMapper.auto_upgrade!

###### HTTP Methods

### Taxi

get '/taxi/:id' do
  raise 404 unless Taxi.get(params[:id]).to_json
end

post '/taxi/create' do
  taxi = Taxi.create(params)
  raise 500 unless taxi.saved?
  return taxi.to_json
end

post '/taxi/update' do
  taxi = Taxi.get(params[:id])
  taxi.update(params)
  raise 500 unless taxi.saved?
  return taxi.to_json
end

### Trip

get '/trip/:id' do
  raise 404 unless Trip.get(params[:id]).to_json
end

post '/trip/create' do
  trip = Trip.create(params)
  raise 500 unless trip.saved?
  return trip.to_json
end

### Passenger

get '/passenger/:id' do
  raise 404 unless Passenger.get(params[:id]).to_json
end

post '/passenger/create' do
  passenger = Passenger.create(params)
  raise 500 unless passenger.saved?
  return passenger.to_json
end

post '/passenger/update' do
  passenger = Passenger.get(params[:id])
  passenger.update(params)
  raise 500 unless passenger.saved?
  return passenger.to_json
end

### Position

get '/position/most_recent' do
  positions = Position.all()
end

post '/position/create' do
  position = Position.create(params)
  raise 500 unless position.saved?
  return position.to_json
end


###### Helpers

def uuid(size=6)
  chars = ('a'..'z').to_a + ('A'..'Z').to_a + (0..9).to_a
  (0...size).collect { chars[Kernel.rand(chars.length)] }.join
end
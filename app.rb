require 'rubygems'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'dm-core'
require 'dm-migrations'
require 'dm-timestamps'
require 'dm-validations'
require 'dm-serializer'
require 'dm-types'
require 'json'

###### Model 

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/database.sqlite3")

class Taxi
  include DataMapper::Resource
  property  :id,              Serial
  property  :first_name,      String,     :required => true,  :length => 100
  property  :last_name,       String,     :required => true,  :length => 100
  property  :license_plates,  String,     :required => true
  property  :password,        BCryptHash, :required => true 
  property  :account_balance, Integer
  property  :score,           Integer
  
  has n, :trips
  has n, :passengers, :through => :trips  
  has n, :positions
end

class Trip
  include DataMapper::Resource
  property  :id,              String,   :key => true,  :default => lambda { |r, p| uuid }
  property  :latitude,        Float
  property  :longitude,       Float
  property  :destination,     String
  property  :created_at,      DateTime
  
  belongs_to :taxi
  belongs_to :passenger
end

class Passenger
  include DataMapper::Resource
  property  :id,              Serial
  property  :first_name,      String,       :length =>  100
  property  :last_name,       String,       :length =>  100
  property  :mobile_phone,    String
  
  has n, :trips
  has n, :taxis,  :through => :trips
end

class Position
  include DataMapper::Resource
  property  :id,              Serial
  property  :latitude,        Float
  property  :longitude,       Float
  property  :status,          Boolean
  property  :created_at,      DateTime
  
  belongs_to :taxi
end

DataMapper.auto_upgrade!

###### HTTP Methods

### Taxi

get '/taxi/:id' do
  content_type :json
  taxi = Taxi.get(params[:id])
  raise 404 unless taxi
  return taxi.to_json
end

post '/taxi/create' do
  content_type :json
  taxi = Taxi.create(params)
  raise 500 unless taxi.saved?
  return taxi.to_json
end

post '/taxi/update' do
  content_type :json
  taxi = Taxi.get(params[:id])
  taxi.update(params)
  raise 500 unless taxi.saved?
  return taxi.to_json
end

### Trip

get '/trip/:id' do
  content_type :json
  trip = Trip.get(params[:id])
  raise 404 unless trip
  return trip.to_json
end

post '/trip/create' do
  content_type :json
  trip = Trip.create(params)
  raise 500 unless trip.saved?
  return trip.to_json
end

### Passenger

get '/passenger/:id' do
  content_type :json
  passenger = Passenger.get(params[:id]).to_json
  raise 404 unless passenger
  return passenger.to_json
end

post '/passenger/create' do
  content_type :json
  passenger = Passenger.create(params)
  raise 500 unless passenger.saved?
  return passenger.to_json
end

post '/passenger/update' do
  content_type :json
  passenger = Passenger.get(params[:id])
  passenger.update(params)
  raise 500 unless passenger.saved?
  return passenger.to_json
end

### Position

get '/position/all' do
  content_type :json
  positions = Position.all
  raise 404 unless positions
  return positions.to_json
end

get '/position/get_closest' do
  content_type :json
  lat = params[:latitude]
  long = params[:longitude]
  interval = 5 #minutes
  query_string = "SELECT distinct(`taxi_id`),`created_at` FROM `positions` WHERE `status`=FALSE AND (EXTRACT(EPOCH FROM now() - `created_at`)/60) < #{interval}  AND ((6371*3.1415926*sqrt((`latitude`-#{lat})*(`latitude`-#{lat}) +cos(#{lat}/57.29578)*cos(`lat`/57.29578)*(#{long}-`longitude`)*(#{long}-`longitude`))/180)<3.0)"
  puts query_string
  positions = repository(:default).adapter.select(query_string)
  return positions.to_json
end

post '/position/create' do
  content_type :json
  taxi = Taxi.get(params[:taxi_id])
  position = taxi.positions.create(params)
  raise 500 unless position.saved?
  status 200
  return position.to_json
end


###### Helpers

def uuid(size=6)
  chars = ('a'..'z').to_a + ('A'..'Z').to_a + (0..9).to_a
  (0...size).collect { chars[Kernel.rand(chars.length)] }.join
end
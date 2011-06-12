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
require 'net/http'
require 'uri'

###### Model 

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/database.sqlite3")

class Taxi
  include DataMapper::Resource
  property  :id,              Serial
  property  :first_name,      String,     :required => true,  :length => 100
  property  :last_name,       String,     :required => true,  :length => 100
  property  :license_plates,  String,     :unique => true
  property  :password,        BCryptHash, :required => true 
  property  :account_balance, Integer
  property  :score,           Integer
  
  has n, :positions
end

class Trip
  include DataMapper::Resource
  property  :id,              String,   :key => true,  :default => lambda { |r, p| uuid }
  property  :latitude,        Float
  property  :longitude,       Float
  property  :destination,     String
  property  :taxi_id,         String
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

get '/test' do
  content_type :json, 'charset' => 'utf-8'
  url = URI.parse('http://maps.google.com/maps/api/geocode/json?sensor=false&address='+URI.escape(params['number']+", "+params['street']+", "+params['neighbourhood']))
  response = JSON.parse(Net::HTTP.get(url).force_encoding('UTF-8'))
  results = response['results']  
  f = results[0]
  geometry = f['geometry']
  location = geometry['location']
  lat = location['lat'].to_s
  lng = location['lng'].to_s
  
  return lat,lng  
end

post '/trip/create' do
  content_type :json
  
  # Turn geo strings into geo coords
  url = URI.parse('http://maps.google.com/maps/api/geocode/json?sensor=false&address='+URI.escape(params['number']+", "+params['street']+", "+params['neighbourhood']))
  response = JSON.parse(Net::HTTP.get(url).force_encoding('UTF-8'))
  results = response['results']  
  f = results[0]
  geometry = f['geometry']
  location = geometry['location']
  lat = location['lat']
  long = location['lng']
  
  # Find closest taxis
  max_minutes = 20
  query_string = 'SELECT DISTINCT ON(taxi_id) taxi_id,created_at FROM positions WHERE ((6371*3.1415926*sqrt((latitude-'+lat.to_s+')*(latitude-19.42705) +cos('+lat.to_s+'/57.29578)*cos(latitude/57.29578)*('+long.to_s+'-longitude)*('+long.to_s+'-longitude))/180)<3.0) AND status=FALSE AND EXTRACT(EPOCH FROM current_timestamp -created_at)/60 <'+max_minutes.to_s
  puts query_string
  results = repository(:default).adapter.select(query_string)
  
  # Notify closest taxis
  results.each do | result |
    #...
  end

  # Store new trip 
  passenger = Passenger.get(params[:passenger_id])
  trip = passenger.trip.create(:latitude => lat, :longitude => long, :destination => params[:destination])
  raise 500 unless trip.saved?
  return trip.to_json
end

get '/test2' do
  content_type :json
  lat = (19.425).to_s
  long = (-99.13).to_s
  max_minutes = 10000
  query_string = 'SELECT DISTINCT ON(taxi_id) taxi_id,created_at FROM positions WHERE ((6371*3.1415926*sqrt((latitude-'+lat+')*(latitude-19.42705) +cos('+lat+'/57.29578)*cos(latitude/57.29578)*('+long+'-longitude)*('+long+'-longitude))/180)<3.0) AND status=FALSE AND EXTRACT(EPOCH FROM current_timestamp -created_at)/60 <'+max_minutes.to_s
  puts query_string
  results = repository(:default).adapter.select(query_string)
  results.each do | result|
    puts result[:taxi_id]
  end
  return results.to_json
end

post '/trip/confirm' do
  content_type :json
  trip = Passenger.get(params[:id])
  
  #Actualiza el registro si no ha sido actualizado
  #Manda SMS al usuario con código
  
  # if trip.taxi_id == nil
  #   return trip.update(params[:taxi_id]).to_json if  
  # else
  
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
  query_string = "SELECT DISTINCT ON(`taxi_id`) `created_at` FROM positions WHERE `status`=FALSE AND (EXTRACT(EPOCH FROM now() - `created_at`)/60) < #{interval}  AND ((6371*3.1415926*sqrt((`latitude`-#{lat})*(`latitude`-#{lat}) +cos(#{lat}/57.29578)*cos(`lat`/57.29578)*(#{long}-`longitude`)*(#{long}-`longitude`))/180)<3.0)"
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

get '/llenar_datos' do
  Position.create(:latitude=>19.429059,:longitude=>-99.126302,:status=>false,:taxi_id=>1)
  Position.create(:latitude=>19.429332,:longitude=>-99.127793,:status=>false,:taxi_id=>2)
  Position.create(:latitude=>19.429059,:longitude=>-99.126302,:status=>false,:taxi_id=>3)
  Position.create(:latitude=>19.427825,:longitude=>-99.127451,:status=>false,:taxi_id=>4)
  Position.create(:latitude=>19.429009,:longitude=>-99.129746,:status=>false,:taxi_id=>5)
  Position.create(:latitude=>19.429059,:longitude=>-99.126302,:status=>false,:taxi_id=>6)
  Position.create(:latitude=>19.428118,:longitude=>-99.129993,:status=>false,:taxi_id=>7)
  Position.create(:latitude=>19.429929,:longitude=>-99.134252,:status=>false,:taxi_id=>8)
  Position.create(:latitude=>19.429606,:longitude=>-99.171352,:status=>false,:taxi_id=>9)  
  Position.create(:latitude=>19.423717,:longitude=>-99.170558,:status=>false,:taxi_id=>10)  
  Position.create(:latitude=>19.423717,:longitude=>-99.190772,:status=>false,:taxi_id=>11)  
  Position.create(:latitude=>19.382733,:longitude=>-99.177682,:status=>false,:taxi_id=>12)  
  Position.create(:latitude=>19.388907,:longitude=>-99.198668,:status=>false,:taxi_id=>13)
end

###### Helpers

def uuid(size=6)
  chars = ('a'..'z').to_a + ('A'..'Z').to_a + (0..9).to_a
  (0...size).collect { chars[Kernel.rand(chars.length)] }.join
end
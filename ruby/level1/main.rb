require 'json'
require 'date'

file = File.read('data/input.json')
data = JSON.parse(file)

cars = data['cars']
rentals = data['rentals']
ouput = { 'rentals' => [] }

rentals.each do |rental|
  number_of_days = Date.parse(rental['end_date']).mjd - Date.parse(rental['start_date']).mjd + 1
  car = cars.select { |car| car['id'] == rental['car_id'] }.first

  total_price_day = car['price_per_day'] * number_of_days
  total_price_km = car['price_per_km'] * rental['distance']
  total_price = total_price_day + total_price_km

  ouput['rentals'] << { id: rental['id'], price: total_price }
end

File.write('data/output.json', JSON.dump(ouput))

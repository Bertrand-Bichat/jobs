require 'json'
require 'date'

file = File.read('data/input.json')
data = JSON.parse(file)

cars = data['cars']
rentals = data['rentals']
ouput = { 'rentals' => [] }

rentals.each do |rental|
  number_of_days = (Date.parse(rental['end_date']).mjd - Date.parse(rental['start_date']).mjd + 1).to_f
  car = cars.select { |car| car['id'] == rental['car_id'] }.first

  price_per_day = car['price_per_day'].to_f
  price_per_day_10_off = price_per_day * 0.9
  price_per_day_30_off = price_per_day * 0.7
  price_per_day_50_off = price_per_day * 0.5

  total_price_day = 0.0
  total_price_day += price_per_day * 1.0 if number_of_days >= 1.0

  total_price_day += if number_of_days > 1.0 && number_of_days < 4.0
                       price_per_day_10_off * (number_of_days - 1.0)
                     elsif number_of_days >= 4.0
                       price_per_day_10_off * 3.0
                     else
                       0.0
                     end

  total_price_day += if number_of_days > 4.0 && number_of_days < 10.0
                       price_per_day_30_off * (number_of_days - 4.0)
                     elsif number_of_days >= 10.0
                       price_per_day_30_off * 6.0
                     else
                       0.0
                     end

  total_price_day += price_per_day_50_off * (number_of_days - 10.0) if number_of_days > 10.0

  total_price_km = car['price_per_km'] * rental['distance']
  total_price = total_price_day.to_i + total_price_km

  commission = total_price.to_f * 0.3
  insurance_fee = (commission * 0.5).to_i
  assistance_fee = (number_of_days * 100).to_i
  drivy_fee = commission.to_i - insurance_fee - assistance_fee

  commission_hash = {
    insurance_fee: insurance_fee,
    assistance_fee: assistance_fee,
    drivy_fee: drivy_fee
  }

  ouput['rentals'] << { id: rental['id'], price: total_price, commission: commission_hash }
end

File.write('data/output.json', JSON.dump(ouput))

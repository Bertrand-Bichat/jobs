require 'json'
require 'date'

file = File.read('data/input.json')
data = JSON.parse(file)

cars = data['cars']
rentals = data['rentals']
options = data['options']
ouput = { 'rentals' => [] }

def calculate_total_price_day(price_per_day, number_of_days)
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
  total_price_day.to_i
end

rentals.each do |rental|
  number_of_days = (Date.parse(rental['end_date']).mjd - Date.parse(rental['start_date']).mjd + 1).to_f
  car = cars.select { |car| car['id'] == rental['car_id'] }.first
  rental_options = options.select { |option| option['rental_id'] == rental['id'] }

  total_price_day = calculate_total_price_day(car['price_per_day'].to_f, number_of_days)

  total_price_gps = 0
  total_price_baby_seat = 0
  total_price_additional_insurance = 0
  options_array = []

  unless rental_options.empty?
    rental_options.each do |option|
      type = option['type']
      options_array << type
      case type
      when 'gps'
        total_price_gps = (500.0 * number_of_days).to_i
      when 'baby_seat'
        total_price_baby_seat = (200.0 * number_of_days).to_i
      when 'additional_insurance'
        total_price_additional_insurance = (1000.0 * number_of_days).to_i
      end
    end
  end

  total_price_km = car['price_per_km'] * rental['distance']
  total_price = total_price_day + total_price_km

  commission = total_price.to_f * 0.3
  insurance_fee = (commission * 0.5).to_i
  assistance_fee = (number_of_days * 100).to_i
  drivy_fee = commission.to_i - insurance_fee - assistance_fee + total_price_additional_insurance
  owner_price = total_price - commission.to_i + total_price_gps + total_price_baby_seat
  debit_driver = total_price + total_price_gps + total_price_baby_seat + total_price_additional_insurance

  actions_array = []
  actions_array << { who: 'driver', type: 'debit', amount: debit_driver }
  actions_array << { who: 'owner', type: 'credit', amount: owner_price }
  actions_array << { who: 'insurance', type: 'credit', amount: insurance_fee }
  actions_array << { who: 'assistance', type: 'credit', amount: assistance_fee }
  actions_array << { who: 'drivy', type: 'credit', amount: drivy_fee }

  ouput['rentals'] << { id: rental['id'], options: options_array, actions: actions_array }
end

File.write('data/output.json', JSON.dump(ouput))

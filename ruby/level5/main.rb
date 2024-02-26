require 'json'
require 'date'

class Car
  attr_accessor :id, :price_per_day, :price_per_km

  def initialize(id:, price_per_day:, price_per_km:)
    @id = id
    @price_per_day = price_per_day
    @price_per_km = price_per_km
  end
end

class Option
  attr_accessor :id, :rental_id, :type

  def initialize(id:, rental_id:, type:)
    @id = id
    @rental_id = rental_id
    @type = type
  end
end

class Rental
  attr_accessor :id, :car_id, :start_date, :end_date, :distance, :number_of_days, :total_price, :options_array,
                :actions_array

  def initialize(id:, car_id:, start_date:, end_date:, distance:)
    @id = id
    @car_id = car_id
    @start_date = start_date
    @end_date = end_date
    @distance = distance

    @number_of_days = calculate_number_of_days

    @total_price = 0
    @options_array = []
    @actions_array = []
  end

  def calculate_number_of_days
    (Date.parse(@end_date).mjd - Date.parse(@start_date).mjd + 1).to_f
  end
end

class CarRentalService
  def initialize(file_path)
    file = File.read(file_path)
    @data = JSON.parse(file)
    @ouput = { 'rentals' => [] }
  end

  def call
    create_instances_from_data
    calculate_total_price_for_each_rentals
    calculate_options_prices_for_each_rentals
    build_output_hash
    write_output_file
  end

  private

  def create_instances_from_data
    create_cars
    create_rentals
    create_options
  end

  def create_cars
    @cars = @data['cars'].map do |car|
      Car.new(id: car['id'], price_per_day: car['price_per_day'], price_per_km: car['price_per_km'])
    end
  end

  def create_rentals
    @rentals = @data['rentals'].map do |rental|
      Rental.new(id: rental['id'], car_id: rental['car_id'], start_date: rental['start_date'],
                 end_date: rental['end_date'], distance: rental['distance'])
    end
  end

  def create_options
    @options = @data['options'].map do |option|
      Option.new(id: option['id'], rental_id: option['rental_id'], type: option['type'])
    end
  end

  def calculate_total_price_for_each_rentals
    @rentals.each do |rental|
      car = @cars.select { |car| car.id == rental.car_id }.first

      distance = rental.distance
      price_per_km = car.price_per_km
      total_price_km = price_per_km * distance

      number_of_days = rental.number_of_days
      price_per_day = car.price_per_day.to_f

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
      total_price_day = total_price_day.to_i

      rental.total_price = total_price_day + total_price_km
    end
  end

  def calculate_options_prices_for_each_rentals
    @rentals.each do |rental|
      rental_options = @options.select { |option| option.rental_id == rental.id }
      number_of_days = rental.number_of_days
      total_price = rental.total_price

      total_price_gps = 0
      total_price_baby_seat = 0
      total_price_additional_insurance = 0

      unless rental_options.empty?
        rental_options.each do |option|
          type = option.type
          rental.options_array << type
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
      rental.actions_array = actions_array
    end
  end

  def build_output_hash
    @rentals.each do |rental|
      @ouput['rentals'] << { id: rental.id, options: rental.options_array, actions: rental.actions_array }
    end
  end

  def write_output_file
    File.write('data/output.json', JSON.dump(@ouput))
  end
end

data = CarRentalService.new('data/input.json').call

require 'json'
require 'date'

class Car
  attr_accessor :id, :price_per_day, :price_per_km

  def initialize(id:, price_per_day:, price_per_km:)
    @id = id
    @price_per_day = price_per_day
    @price_per_km = price_per_km
  end

  def self.create_multiple(cars)
    cars.map { |car| Car.new(id: car['id'], price_per_day: car['price_per_day'], price_per_km: car['price_per_km']) }
  end

  def self.find(cars, car_id)
    cars.select { |car| car.id == car_id }.first
  end
end

class Option
  attr_accessor :id, :rental_id, :type

  def initialize(id:, rental_id:, type:)
    @id = id
    @rental_id = rental_id
    @type = type
  end

  def self.create_multiple(options)
    options.map { |option| Option.new(id: option['id'], rental_id: option['rental_id'], type: option['type']) }
  end

  def self.find(options, rental_id)
    options.select { |option| option.rental_id == rental_id }
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
    Date.parse(@end_date).mjd - Date.parse(@start_date).mjd + 1
  end

  def self.create_multiple(rentals)
    rentals.map do |rental|
      Rental.new(id: rental['id'], car_id: rental['car_id'], start_date: rental['start_date'], end_date: rental['end_date'],
                 distance: rental['distance'])
    end
  end
end

class CalculateRentalTotalPrice
  def initialize(rentals, cars)
    @rentals = rentals
    @cars = cars
  end

  def call
    @rentals.each do |rental|
      find_data(rental)
      calculate_total_price_km(@price_per_km, @distance)
      calculate_total_price_day(@price_per_day, @number_of_days)
      rental.total_price = @total_price_day + @total_price_km
    end
  end

  private

  def find_data(rental)
    @car = Car.find(@cars, rental.car_id)
    @distance = rental.distance
    @number_of_days = rental.number_of_days
    @price_per_km = @car.price_per_km
    @price_per_day = @car.price_per_day
  end

  def calculate_total_price_km(price_per_km, distance)
    @total_price_km = price_per_km * distance
  end

  def calculate_total_price_day(price_per_day, number_of_days)
    price_per_day_10_off = price_per_day * 0.9
    price_per_day_30_off = price_per_day * 0.7
    price_per_day_50_off = price_per_day * 0.5

    @total_price_day = 0.0
    @total_price_day += price_per_day * 1 if number_of_days >= 1

    @total_price_day += if number_of_days > 1 && number_of_days < 4
                          price_per_day_10_off * (number_of_days - 1)
                        elsif number_of_days >= 4
                          price_per_day_10_off * 3
                        else
                          0
                        end

    @total_price_day += if number_of_days > 4 && number_of_days < 10
                          price_per_day_30_off * (number_of_days - 4)
                        elsif number_of_days >= 10
                          price_per_day_30_off * 6
                        else
                          0
                        end

    @total_price_day += price_per_day_50_off * (number_of_days - 10) if number_of_days > 10
    @total_price_day = @total_price_day.to_i
  end
end

class CalculateOptionsTotalPrice
  def initialize(rentals, options)
    @rentals = rentals
    @options = options
  end

  def call
    @rentals.each do |rental|
      find_data(rental)
      calculate_options_prices(rental)
      calculate_final_prices
      build_output_actions(rental)
    end
  end

  private

  def find_data(rental)
    @rental_options = Option.find(@options, rental.id)
    @number_of_days = rental.number_of_days
    @total_price = rental.total_price
  end

  def calculate_options_prices(rental)
    @total_price_gps = 0
    @total_price_baby_seat = 0
    @total_price_additional_insurance = 0
    return if @rental_options.empty?

    @rental_options.each do |option|
      type = option.type
      rental.options_array << type
      @total_price_gps = 500 * @number_of_days if type == 'gps'
      @total_price_baby_seat = 200 * @number_of_days if type == 'baby_seat'
      @total_price_additional_insurance = 1000 * @number_of_days if type == 'additional_insurance'
    end
  end

  def calculate_final_prices
    @commission = (@total_price * 0.3).to_i
    @insurance_fee = (@commission * 0.5).to_i
    @assistance_fee = @number_of_days * 100
    @drivy_fee = @commission - @insurance_fee - @assistance_fee + @total_price_additional_insurance
    @owner_price = @total_price - @commission + @total_price_gps + @total_price_baby_seat
    @debit_driver = @total_price + @total_price_gps + @total_price_baby_seat + @total_price_additional_insurance
  end

  def build_output_actions(rental)
    actions_array = []
    actions_array << { who: 'driver', type: 'debit', amount: @debit_driver }
    actions_array << { who: 'owner', type: 'credit', amount: @owner_price }
    actions_array << { who: 'insurance', type: 'credit', amount: @insurance_fee }
    actions_array << { who: 'assistance', type: 'credit', amount: @assistance_fee }
    actions_array << { who: 'drivy', type: 'credit', amount: @drivy_fee }
    rental.actions_array = actions_array
  end
end

class ParseJsonCarRental
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
    @cars = Car.create_multiple(@data['cars'])
    @rentals = Rental.create_multiple(@data['rentals'])
    @options = Option.create_multiple(@data['options'])
  end

  def calculate_total_price_for_each_rentals
    CalculateRentalTotalPrice.new(@rentals, @cars).call
  end

  def calculate_options_prices_for_each_rentals
    CalculateOptionsTotalPrice.new(@rentals, @options).call
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

data = ParseJsonCarRental.new('data/input.json').call

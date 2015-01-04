require 'securerandom'
require 'nokogiri'
require 'csv'
require File.join(File.dirname(__FILE__), 'order_item_parser')

# Code Test Instructions:
# * Write a ruby script/program that can parse this Amazon XML file (faster and smaller memory usage is always best).
# * Save each order as a row in a csv file or database table.
#
# TODO: It may be possible to receive a file with hundreds or thousands of orders. So we may need to batch this process.

# This class is used to parse an order XML file.
class Parser
  attr_reader :result_file_path
  class NoFileFound < StandardError; end

  BATCH_SIZE = 100

  # Constructs a new instance of the Parser class
  # @param path [String] the file path of the XML order file
  def initialize(path)
    @file_path = path
    raise NoFileFound unless File.exists?(@file_path)
    unless Dir.exist?(File.join(File.dirname(__FILE__), 'results'))
      raise "Please create a results directory in the project root."
    end

    @result_file_path = File.join(File.dirname(__FILE__), 'results', "parsed_orders_#{SecureRandom.hex}.csv")
  end

  def call
    correct_xml_file if file_line_count < 10
    line_number = 0

    f = File.open(File.path(@file_path), 'r')

    # skip the top of the document
    while (line = f.gets) do
      line_number += 1
      break if line.include?('<Message>')
    end

    result_file = File.open(@result_file_path, 'wb+')
    result_file.close

    # The default here is writing the results to a csv but this could easily be exchanged for writing to a DB.
    CSV.open(@result_file_path, 'wb+') do |csv|
      csv << ['OrderID', 'Purchase Date', 'Order Status', 'Last Updated', 'Items', 'Subtotal', 'Tax', 'Shipping', 'Discounts', 'Total Paid', 'Shipping Address', 'Fullfillment Channel', 'Shipping Service Level']

      order_count.times do |i|
        xml_order = Nokogiri.XML(build_order(f))
        order = {}

        order_status = xml_order.xpath("//OrderStatus").first.content
        sales_channel = xml_order.xpath("//SalesChannel").first.content

        next if sales_channel != 'Amazon.com'

        order_item_statuses = xml_order.xpath('//OrderItem').map{ |order_item| order_item.xpath('//ItemStatus').first.content }

        # only include Shipped or Partially shipped orders
        if order_status != 'Shipped'
          if order_item_statuses.all?{ |status| status == 'Unshipped'}
            puts "skipping order #{xml_order.css('AmazonOrderID').first.content}"
            next
          end
        end

        # * Find all orders in a Shipped or Partially Shipped Status.
        # * Exclude Non-Amazon Sales Channel orders.
        # Order ID, Status, Purchase Date, Updated Date, Item Count, item subtotal, Tax, Shipping,
        # Discounts, Total Paid, Shipping Address, Fulfillment Info

        order[:id] = xml_order.xpath("//AmazonOrderID").first.content
        order[:purchase_date] = xml_order.xpath("//PurchaseDate").first.content
        order[:order_status] = order_status
        order[:last_updated_date] = xml_order.xpath("//LastUpdatedDate").first.content
        order[:item_count] = xml_order.xpath("//OrderItem").count
        order[:fullfillment_channel] = xml_order.xpath("//FulfillmentChannel").first.content
        order[:shipping_service_level] = xml_order.xpath("//ShipServiceLevel").first.content
        order[:total_paid] = 0.00 # there are not fields that seem to distinguish payment
        money_pieces = get_amounts_from_order_items(xml_order.xpath("//OrderItem"))

        xml_address = xml_order.xpath('//FulfillmentData').first.xpath('//Address').first

        order[:shipping_address] = "#{xml_address.xpath('//City').first.content}"
        order[:shipping_address] << " #{xml_address.xpath('//State').first.content}, "
        order[:shipping_address] << " #{xml_address.xpath('//PostalCode').first.content}"
        order[:shipping_address] << " #{xml_address.xpath('//Country').first.content}"

        # TODO: calculate subtotal for all items in the order
        # order[:item_subtotal] = xml_order.xpath("//OrderItem").count

        csv << [
          order[:id],
          order[:purchase_date],
          order[:order_status],
          order[:last_updated_date],
          order[:item_count],
          money_pieces[:subtotal].to_s,
          money_pieces[:tax].to_s,
          money_pieces[:shipping].to_s,
          money_pieces[:shipping].to_s,
          order[:total_paid],
          order[:shipping_address],
          order[:fullfillment_channel],
          order[:shipping_service_level],
        ]
      end
    end

    f.close

    return @result_file_path
  end

  private

  # @private
  #
  # Extracts the total subtotal, tax, and shipping amount for all the order items
  # @param order_items [Nokogiri::Node] the array or Node of order items
  # @return [Hash] the totals as a hash
  def get_amounts_from_order_items(order_items)
    total_tax = 0.00
    total_shipping = 0.00
    total_subtotal = 0.00
    total_discounts = 0.00

    order_items.each do |order_item|
      order_item_parser = OrderItemParser.new(order_item)
      order_item_parser.call

      total_shipping =+ order_item_parser.shipping
      total_subtotal =+ order_item_parser.subtotal
      total_tax =+ order_item_parser.tax
      total_discounts =+ order_item_parser.discount
    end

    { :subtotal => total_subtotal, :tax => total_tax, :shipping => total_shipping }
  end

  # @private
  #
  # Extracts an individual order from the file
  # @param f [FileHandler] the file handler from the opened XML order file.
  # @return xml_order [String] The XML order section
  def build_order(f)
    xml_order = ""

    while (line = f.gets) do
      xml_order << line
      break if line.include?('</Message>')
    end
    xml_order
  end

  # @private
  #
  # Formats the XML file into a properly formatted XML document so we can parse it.
  # @return void
  def correct_xml_file
    doc = Nokogiri.XML(File.read(@file_path)) do |config|
      config.default_xml.noblanks
    end

    File.open(@file_path, 'wb+'){ |f| f.write(doc.to_xml(:indent => 2)) }
  end

  # @private
  #
  # Returns the number of lines in the given file. This is used to detect inproperly formatted XML documents. If an XML document does not
  # have a reasonable number of lines we assume it is improperly formatted.
  # @return file_line_count [Integer] the number of lines in the file
  def file_line_count
    @file_line_count ||= File.open(@file_path, 'r').readlines.size
  end

  # @private
  #
  # Returns the number of orders in the given file. This is used to break up the order processing into batches for speed and memory
  # utilization purposes.
  # @return order_count [Integer] the number of orders in the file
  def order_count
    @order_count ||= `fgrep -l "</Order>" #{File.path(@file_path)}`.size
  end
end

require 'securerandom'
require 'nokogiri'

# Code Test Instructions:
# * Write a ruby script/program that can parse this Amazon XML file (faster and smaller memory usage is always best).
# * Find all orders in a Shipped or Partially Shipped Status.
# * Exclude Non-Amazon Sales Channel orders.
# * Save each order as a row in a csv file or database table.
# ** Each row should have the Order ID, Status, Purchase Date, Updated Date, Item Count, item subtotal, Tax, Shipping, Discounts, Total Paid, Shipping Address, Fulfillment Info

class Parser
  class NoFileFound < StandardError; end

  BATCH_SIZE = 100

  def initialize(path)
    @file_path = path
    raise NoFileFound unless File.exists?(@file_path)

    @result_file_path = File.join(File.dirname(__FILE__), '..', 'results', "parsed_orders_#{SecureRandom.hex}.csv")
  end

  def call
    correct_xml_file if file_line_count < 10
    start_time  = Time.now
    batch_count = (order_count.to_f / BATCH_SIZE).ceil
    line_number = 0

    f = File.open(File.path(@file_path), 'r')

    # skip the top of the document
    while (line = f.gets) do
      line_number += 1
      puts "skipping #{line}"
      break if line.include?('<Message>')
    end

    CSV.open(@result_file_path, 'wb+') do |csv|
      csv << ['OrderID', 'Purchase Date', 'Order Status', 'Last Updated', 'Items', 'Subtotal']

      order_count.times do |i|
        xml_order = Nokogiri.XML(build_order(f))
        order = {}

        order_status = xml_order.xpath("//OrderStatus").first.content
        sales_channel = xml_order.xpath("//SalesChannel").first.content

        next if sales_channel != 'Amazon.com' || !['Partially Shipped', 'Shipped'].include?(order_status.downcase)

        # * Find all orders in a Shipped or Partially Shipped Status.
        # * Exclude Non-Amazon Sales Channel orders.
        # Order ID, Status, Purchase Date, Updated Date, Item Count, item subtotal, Tax, Shipping,
        # Discounts, Total Paid, Shipping Address, Fulfillment Info

        order[:id] = xml_order.xpath("//AmazonOrderID").first.content
        order[:purchase_date] = xml_order.xpath("//PurchaseDate").first.content
        order[:order_status] = order_status
        order[:last_updated_date] = xml_order.xpath("//LastUpdatedDate").first.content
        order[:item_count] = xml_order.xpath("//OrderItem").count

        # TODO: calculate subtotal for all items in the order
        # order[:item_subtotal] = xml_order.xpath("//OrderItem").count

        csv << [
          order[:id],
          order[:purchase_date],
          order[:order_status],
          order[:last_updated_date],
          order[:item_count],
          order[:subtotal],
          order[:tax],
          order[:shipping],
          order[:discounts],
          order[:total_paid],
          order[:shipping_address],
          order[:fullfillment_info]
        ]
      end
    end

    f.close

    # measure the performance of parsing and writing to CSV
    elapsed_time = ((Time.now - start_time) / 60).to_i
    puts elapsed_time

    return @result_file_path
  end

  private

  def build_order(f)
    xml_order = ""

    while (line = f.gets) do
      xml_order << line
      puts "writing #{line}"
      break if line.include?('</Message>')
    end
    xml_order
  end

  def correct_xml_file
    doc = Nokogiri.XML(File.read(@file_path)) do |config|
      config.default_xml.noblanks
    end

    File.open(@file_path, 'wb+'){ |f| f.write(doc.to_xml(:indent => 2)) }
  end

  def file_line_count
    @file_line_count ||= File.open(@file_path, 'r').readlines.size
  end

  def order_count
    @order_count ||= `fgrep -l "</Order>" #{File.path(@file_path)}`.size
  end
end

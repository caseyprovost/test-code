# This class is used to parser an order item.
# It calculates all of it's totals based on the contained XML
class OrderItemParser
  attr_reader :shipping, :tax, :subtotal, :discount

  # Constructs a new instance of the OrderItemParser class
  # @param order_item [String] XML representation of an order item
  def initialize(order_item)
    @order_item = order_item
    @parsed = false
  end

  # Calculates the subtotal, tax, and shipping amounts for a given order item.
  # It will only attempt to calculate once.
  def call
    return if @parsed

    @tax = 0.00
    @shipping = 0.00
    @subtotal = 0.00
    @discount = 0.00

    quantity = @order_item.xpath("//Quantity").first.content.to_i
    components = @order_item.xpath("//Component")
    amounts = get_amounts_from_components(components)

    @tax =+ (amounts[:tax] * quantity)
    @shipping =+ (amounts[:shipping] * quantity)
    @subtotal =+ (amounts[:subtotal] * quantity)

    promotions = @order_item.xpath('//Promotion')

    # There appears to only be shipping promtions
    if promotions.any?
      shipping_promotion = promotions.xpath('//ShipPromotionDiscount').map{ |node| node.content.to_f }.inject{ |sum, amount| sum + amount }
      @discount =+ (shipping_promotion * quantity)
    end

    if @tax < 0.00 || @shipping < 0.00 || @subtotal < 0.00
      # code to help debug
      # raise @order_item.to_xml.inspect
      raise StandardError.new("order item has a negative value for tax or shipping or subtotal")
    end

    @parsed = true
  end

  private

  # @private
  # Extracts and totals the tax, shipping, and subtotal of each "Component" of an order item
  def get_amounts_from_components(components)
    tax = 0.00
    shipping = 0.00
    subtotal = 0.00

    components.each do |component|
      type = component.css('Type').first.content

      case type
      when 'Principal'
        component.css("Amount").each do |amount|
          subtotal += amount.content.to_f
        end
      when 'GiftWrap'
        component.css("Amount").each do |amount|
          subtotal += amount.content.to_f
        end
      when 'Shipping'
        component.css("Amount").each do |amount|
          shipping += amount.content.to_f
        end
      when 'Tax'
        component.css("Amount").each do |amount|
          tax += amount.content.to_f
        end
      when 'GiftWrapTax'
        component.css("Amount").each do |amount|
          tax += amount.content.to_f
        end
      else
        raise StandardError.new("Unknown component type: #{type}")
      end
    end

    { :subtotal => subtotal, :tax => tax, :shipping => shipping }
  end
end

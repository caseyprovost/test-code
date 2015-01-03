# This class is used to parser an order item.
# It calculates all of it's totals based on the contained XML
class OrderItemParser
  attr_reader :shipping, :tax, :subtotal

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

    quantity = @order_item.xpath("//Quantity").first.content.to_i
    components = @order_item.xpath("//Component")
    amounts = get_amounts_from_components(components)

    @tax =+ (amounts[:tax] * quantity)
    @shipping =+ (amounts[:shipping] * quantity)
    @subtotal =+ (amounts[:subtotal] * quantity)

    promotions = @order_item.xpath('//Promotion')

    # There appears to only be shipping promtions
    if promotions.any?
      shipping_promotion = promotions.xpath('//ShipPromotionDiscount').map{ |node| node.content.to_f }.inject{|sum, amount| sum + amount }
      @shipping =- shipping_promotion
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
      type = component.xpath("//Type").first.content

      case type
      when 'Principal'
        component.xpath("//Amount").each do |amount|
          subtotal += amount.content.to_f
        end
      when 'GiftWrap'
        component.xpath("//Amount").each do |amount|
          subtotal += amount.content.to_f
        end
      when 'Shipping'
        component.xpath("//Amount").each do |amount|
          shipping += amount.content.to_f
        end
      when 'Tax'
        component.xpath("//Amount").each do |amount|
          tax += amount.content.to_f
        end
      else
        raise StandardError.new("Unknown component type: #{type}")
      end
    end

    { :subtotal => subtotal, :tax => tax, :shipping => shipping }
  end
end

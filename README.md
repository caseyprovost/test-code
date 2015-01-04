Amazon test code parser
=========

### Repo Setup
**Important**
Make sure you create a results folder at the project root!

### Usage
We often get poorly formatted XML documents containing order information. This parsing library is meant to format those documents and generate a CSV of all the order information.

### Excluded Orders
Due to how we process orders, this parsing library ignores a few types of orders including: 

* Non-Amazon Sales Channel orders
* Orders that have not been shipped

### CSV Fields

* OrderID
* Purchase Date
* Order Status
* Last Updated
* Items (the count of items in the order)
* Subtotal
* Tax
* Shipping
* Discounts
* Total Paid (this will always be 0, there is no paid data in the XML file)
* Shipping Address (does not include street address for some odd reason)
* Fullfillment Channel
* Shipping Service Level (the type of shipping for the order ex: next day, ground, etc)

-- Flattens the generated orders from the landing topic into a curated topic. The topic and its
-- Avro schema are created by this statement. Revisit the projection once you have inspected the
-- schema Ida's connector registered.
CREATE TABLE `${curated_orders_topic}` AS
SELECT
  orderid,
  itemid,
  orderunits,
  ordertime,
  address.city AS city,
  address.state AS state,
  address.zipcode AS zipcode
FROM `${orders_topic}`;

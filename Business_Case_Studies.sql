-- =========================================
-- ZOMATO BUSINESS ANALYTICS PROJECT
-- =========================================

use business_analytics;

-- =========================================
-- SECTION 1 : KPI ANALYSIS
-- =========================================

-- 

--  Total Revenue :

select sum(amount) from orders
as Total_Revenue
where status = 'delivered';

--  Total Orders :

select count(order_id) from orders
as Total_Orders 
where status = 'delivered';


--  Average Order Value

select round(avg(amount),2) as AOV
from orders
where status = 'delivered' ;

--  Total Customers

select count(distinct customer_id) 
as Total_Customers
from orders
where status = 'Delivered';



-- =========================================
-- SECTION 2 : TIME-BASED ANALYSIS
-- =========================================

--  Monthly Revenue Trend

select
date_format(order_date,'%Y-%m') as Month,
sum(amount) as revenue
from orders where status = 'delivered'
group by Month
order by Month;

--  Monthly Order Volume

select 
date_format(order_date,'%Y-%m') as Month,
count(order_id) as total_orders
from orders where status = 'delivered'
group by Month
order by Month;

--  Daily Revenue Trend

select
order_date,
sum(amount) as daily_total
from orders
where status = 'delivered'
group by order_date
order by order_date;

--  Peak Ordering Weekdays

select
dayname(order_date) as weekday,
count(order_id) as total_orders
from orders
where status = 'delivered'
group by weekday
order by total_orders desc;


-- =========================================
-- SECTION 3 : COHORT ANALYSIS
-- =========================================

--  Customer First Order Month

with first_order as(
select
customer_id,
min(order_date) as first_order_date
from orders
where status = 'delivered'
group by customer_id
)
select 
customer_id,
first_order_date,
date_format(first_order_date,'%Y-%m') as cohort_month
from first_order
order by first_order_date;



--  Cohort Retention Analysis

with cohort as(
select
customer_id,
min(order_date) as first_order_date
from orders
where status = 'delivered'
group by customer_id),
activity as(
select o.customer_id,
date_format(c.first_order_date,'%Y-%m') as cohort_month,
date_format(o.order_date,'%Y-%m') as order_month
from orders o join cohort c
on o.customer_id = c.customer_id
where status = 'delivered')
select
cohort_month,
order_month,
count(distinct customer_id) as active_customers
from activity
group by cohort_month,order_month
order by cohort_month,order_month;


-- Cohort Retention Index

with first_order as(
select
customer_id,
min(order_date) as first_order_date
from orders
where status = 'delivered' 
group by customer_id),

customer_activity as(
select o.customer_id,
date_format(f.first_order_date,'%Y-%m') as cohort_month,
date_format(o.order_date,'%Y-%m') as order_month,
timestampdiff(month,f.first_order_date,o.order_date) as retention_month
from orders o join first_order f
on o.customer_id = f.customer_id
where o.status = 'delivered'
)

select cohort_month,retention_month,
count(distinct customer_id) as retained_customers
from customer_activity
group by cohort_month,retention_month
order by cohort_month,retention_month;


-- =========================================
-- SECTION 4 : WINDOW FUNCTIONS
-- =========================================

-- Rank Restaurants By Revenue

select r.restaurant_id,
sum(o.amount) as total_revenue,
rank() 
over(order by sum(o.amount) desc) as revenue_rnk
from orders o join restaurants r
on o.restaurant_id = r.restaurant_id
where status = 'delivered'
group by r.restaurant_id;


--  Cumulative Monthly Revenue

with monthly_revenue as(
select
date_format(order_date,'%Y-%m') as month,
sum(amount) as revenue
from orders
where status = 'delivered'
group by month
)
select month,
revenue,
sum(revenue) 
over(order by month) as cumulative_revenue
from monthly_revenue;


--  Month-over-Month Revenue Growth

with monthly_revenue as(
select
date_format(order_date,'%Y-%m') as month,
sum(amount) as revenue
from orders 
where status = 'delivered'
group by month
)
select month,revenue,
lag(revenue)
over(order by month ) as previous_month_revenue,
((revenue-lag(revenue) over(order by month))/lag(revenue) over(order by month))*100.0
as mom_growth_percent
from monthly_revenue;


-- =========================================
-- SECTION 5 : CUSTOMER SEGMENTATION
-- =========================================

--  Customer Spending Segmentation

with customer_spending as(
select
customer_id,
sum(amount) as total_spent
from orders
where status = 'delivered'
group by customer_id
)
select customer_id,
total_spent,
case when total_spent >= 5000 then 'High Value'
	 when total_spent between 2000 and 4999 
     then 'Medium Value'
     else 'Low Value' end as customer_segment
from customer_spending
order by total_spent desc;


--  Repeat vs One-Time Customers

with customer_orders as(
select
customer_id,
count(order_id) as total_orders
from orders
where status = 'delivered'
group by customer_id
)
select
case when total_orders = 1
then 'One Time Customer'
else 'Repeat Customer'
end as customer_type,
count(customer_id) as total_customers
from customer_orders
group by customer_type;


-- =========================================
-- SECTION 6 : FUNNEL & OPERATIONAL ANALYTICS
-- =========================================

--  Order Funnel Analysis

select
status,
count(order_id) as total_orders,
round((count(order_id)*100.0)/(select count(*) from orders),2)
as percentage_of_orders
from orders
group by status;


--  Average Delivery Time

select
round(avg(timestampdiff(day,order_date,delivery_date)),2)
as avg_delivery_day
from deliveries;


--  Delayed Deliveries

select
delivery_id,
order_id,
datediff(delivery_date,order_date) as delivery_days
from deliveries
where datediff(delivery_date,order_date) > 1
order by delivery_days desc;


-- =========================================
-- SECTION 7 : RESTAURANT PERFORMANCE ANALYTICS
-- =========================================

--  Top Restaurants By Revenue

select 
r.name,
count(o.order_id) as total_orders,
sum(o.amount) as total_revenue,
avg(o.amount) as avg_order_value
from orders o join restaurants r
on o.restaurant_id = r.restaurant_id
where o.status = 'delivered'
group by r.name
order by total_revenue desc;


--  Cuisine Performance Analysis

select
r.cuisine,
count(o.order_id) as total_orders,
sum(o.amount) as total_revenue,
round(avg(o.amount),2) as avg_order_value
from orders o join restaurants r
on o.restaurant_id = r.restaurant_id
where o.status = 'delivered'
group by r.cuisine
order by total_revenue desc;


--  City-wise Performance Analysis

select c.city_name,
count(o.order_id) as total_orders,
sum(o.amount) as total_revenue,
round(avg(o.amount),2) as avg_order_value,
count(distinct cu.customer_id) as unique_customers
from orders o join customers cu 
on o.customer_id = cu.customer_id
join cities c on
cu.city_id = c.city_id
where status = 'delivered'
group by c.city_name;


-- =========================================
-- SECTION 8 : ADVANCED BUSINESS CASE STUDIES
-- =========================================

--  Top 10 Customers By Lifetime Value


select
c.customer_id,
c.name,
count(o.order_id) as total_orders,
sum(o.amount) as lifetime_value,
round(avg(o.amount),2) as avg_order_value
from customers c join orders o
on c.customer_id = o.customer_id
where o.status = 'delivered'
group by c.customer_id, c.name
order by lifetime_value desc
limit 10;


--  Customers At Risk Of Churn

select
customer_id,
max(order_date) as last_order_date,
datediff(curdate(),max(order_date))
as days_since_last_order
from orders
where status = 'delivered'
group by customer_id
having days_since_last_order > 30
order by days_since_last_order desc;


--  Restaurant Rating Performance

select
r.name as restaurant_name,
count(rt.rating_id) as total_ratings,
round(avg(food_rating),2) as avg_food_rating,
round(avg(delivery_rating),2) as avg_del_rating
from ratings rt join orders o
on rt.order_id = o.order_id
join restaurants r 
on r.restaurant_id = o.restaurant_id
group by r.name
having total_ratings >=5
order by avg_food_rating,avg_del_rating;


--  Best-Selling Menu Items

select 
m.item_id,
m.item_name,
count(oi.order_item_id) as total_orders,
sum(oi.quantity*oi.unit_price) as total_sales
from order_items oi join orders o 
on oi.order_id = o.order_id
join menu_items m on
o.restaurant_id = m.restaurant_id
group by m.item_id,m.item_name
order by total_sales;



--  Underperforming Restaurants

select 
r.name as restaurant_name,
count(distinct o.order_id) as total_orders,
sum(o.amount) as total_revenue,
avg(rt.food_rating) as avg_food_rating
from restaurants r
join orders o
on r.restaurant_id = o.restaurant_id
and o.status = 'delivered'
join ratings rt
on o.order_id = rt.order_id
group by r.name
having total_orders < 10
or avg_food_rating < 3.5
order by total_revenue asc;


--  Cancellation Analysis By City

select 
c.city_name,
count(o.order_id) as total_orders,
sum(case when o.status = 'Cancelled'
	then 1 else 0 end) as cancelled_orders,
round((sum(case when o.status = 'Cancelled'
	then 1 else 0 end) *100.0)/ count(o.order_id),2)
    as cancellation_rate_percent
from orders o join customers cu
on o.customer_id = cu.customer_id
join cities c
on cu.city_id = c.city_id
group by c.city_name
order by cancellation_rate_percent desc;


use business_analytics;

--  Monthly Retention Percentage

with first_order 
as(
select customer_id,
min(order_date) as first_order_date
from orders
where status = 'delivered'
group by customer_id),
customer_activity 
as( select 
o.customer_id,
date_format(f.first_order_date,'%Y-%m') as cohort_month,
timestampdiff(month,f.first_order_date,o.order_date) 
as retention_month
from orders o join first_order f
on o.customer_id = f.customer_id
where status = 'delivered'),
cohort_size as(
select cohort_month,
count(distinct customer_id) as total_customers
from customer_activity
where retention_month = 0
group by cohort_month)
select ca.cohort_month,
ca.retention_month,
round((count(distinct ca.customer_id)*100.0)/cs.total_customers,2)
 as retention_percentage
 from customer_activity ca 
 join cohort_size cs
 on ca.cohort_month = cs.cohort_month
 group by
 ca.cohort_month,
 ca.retention_month,
 cs.total_customers
 order by 
 ca.cohort_month,
 ca.retention_month;
 
 
 -- Monthly Active Customers
 
 select 
 date_format(order_date,'%Y-%m') as month,
 count(distinct customer_id)
 as monthly_active_customers
 from orders
 where status = 'delivered'
 group by month
 order by month;
 
 -- Monthly Repeat Customer Rate
 
 with customer_monthly_orders as(
 select
 customer_id,
 date_format(order_date,'%Y-%m') as month,
 count(order_id) as total_orders
 from orders
 where status = 'delivered'
 group by customer_id, month
 )
 select month,
 count(distinct customer_id) as total_customers,
 count(distinct case when total_orders > 1 
 then customer_id end) as repeat_customers,
 round((count(distinct case when total_orders > 1
 then customer_id end)*100.0)/
 count(distinct customer_id),2) as repeat_customer_rate
 from customer_monthly_orders
 group by month
 order by month;
 
 
 --  Top Customers By Order Frequency
 
 with most_order as(
 select customer_id,
 count(order_id) as total_orders
 from orders
 where status = 'delivered'
 group by customer_id)
 select m.customer_id,
 c.name,
 m.total_orders,
 rank() over(order by m.total_orders desc) as rnk
 from most_order m join customers c
 on c.customer_id = m.customer_id
 where total_orders >= 5
 order by rnk;



--  Monthly Revenue Contribution By City

select 
date_format(o.order_date,'%Y-%m') as month,
c.city_name,
sum(o.amount) as city_revenue
from orders o join customers cu
on o.customer_id = cu.customer_id join
cities c on
cu.city_id = c.city_id
where o.status = 'delivered'
group by month,
c.city_name
order by month,
city_revenue;


--  Customer Value Analysis

select customer_id,
datediff(curdate(),max(order_date)) as recency_days,
count(order_id) as frequency,
sum(amount) as monetory_value
from orders
where status = 'delivered'
group by customer_id
order by monetory_value desc, frequency desc;




-- =========================================
-- POWER BI DATASETS
-- =========================================

-- View 1 : Executive KPI Dataset

create view executive_kpi_dataset as

select
	o.order_id,

    o.order_date,

    c.city_name,

    r.name as restaurant_name,

    r.cuisine,

    cu.customer_id,

    o.amount,

    o.status

from orders o

join customers cu
on o.customer_id = cu.customer_id

join cities c
on cu.city_id = c.city_id

join restaurants r
on o.restaurant_id = r.restaurant_id;


-- View 2 : Customer Analytics Dataset

create view customer_analytics_dataset as

select
	o.customer_id,
    cu.name as customer_name,
    c.city_name,
    o.order_id,
    o.order_date,
    o.amount,
    datediff(
		curdate(),
        o.order_date
    ) as days_since_order
from orders o
join customers cu
on o.customer_id = cu.customer_id
join cities c
on cu.city_id = c.city_id

where o.status = 'Delivered';



-- View 3 : Operations Dataset

create view operations_dataset as

select
	o.order_id,
    o.order_date,
    o.status,
    o.amount,
    r.name as restaurant_name,
    r.cuisine,
    c.city_name,
    rt.food_rating,
    rt.delivery_rating,
    d.delivery_date,

    datediff(
		d.delivery_date,
        d.order_date
    ) as delivery_days

from orders o

join customers cu
on o.customer_id = cu.customer_id

join cities c
on cu.city_id = c.city_id

join restaurants r
on o.restaurant_id = r.restaurant_id

left join ratings rt
on o.order_id = rt.order_id

left join deliveries d
on o.order_id = d.order_id;


use business_analytics;

ALTER USER 'root'@'localhost'
IDENTIFIED WITH mysql_native_password
BY 'password';

FLUSH PRIVILEGES;



select * from operations_dataset;

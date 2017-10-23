with
ordered_items as (
  select id, value from items where id in ('103', '104', '202', '308')
),

used_coupons as (
  select * from coupons where id in ('C001', 'C004', 'C006')
),

available_sets as (
  select * from sets
    where elm1 in (select id from ordered_items)
      and elm2 in (select id from ordered_items)
      and elm3 in (select id from ordered_items)
),

enabled_single_coupons as (
  select * from coupons
    where id in (select id from used_coupons)
      and target_id in (select id from ordered_items)
),

enabled_set_coupons as (
  select * from coupons
    where id in (select id from used_coupons)
      and target_id in (select id from available_sets)
),

sets_without_set_coupons as (
  select
    available_sets.id,
    available_sets.elm1,
    available_sets.elm2,
    available_sets.elm3,    
    values1.value + values2.value + values3.value + sum(enabled_single_coupons.value)
      - available_sets.value as value_without_set_coupons
      
    from available_sets
      inner join ordered_items as values1 on (available_sets.elm1 = values1.id)
      inner join ordered_items as values2 on (available_sets.elm2 = values2.id)
      inner join ordered_items as values3 on (available_sets.elm3 = values3.id)
      inner join enabled_single_coupons on enabled_single_coupons.target_id in (elm1, elm2, elm3)
    group by
      available_sets.id
)

select
  sets_without_set_coupons.id,
  sets_without_set_coupons.elm1,
  sets_without_set_coupons.elm2,
  sets_without_set_coupons.elm3,
  sets_without_set_coupons.value_without_set_coupons - ifnull(enabled_set_coupons.value, 0)

  from sets_without_set_coupons
    left join enabled_set_coupons on enabled_set_coupons.target_id = sets_without_set_coupons.id
;  

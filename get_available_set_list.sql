<<"SQL" # Perl 側でプレースホルダを埋め込むためにヒアドキュメントとして扱う
with
ordered_items as (
  select id, value from items where id in ($order_placeholders)
),

used_coupons as (
  select * from coupons where id in ($coupon_placeholders)
),

available_sets as (
  select * from sets
    where elm1 in (select id from ordered_items) -- セットの要素の ID
      and elm2 in (select id from ordered_items) -- セットの要素の ID
      and elm3 in (select id from ordered_items) -- セットの要素の ID
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
    available_sets.id,                  -- セットの ID
    available_sets.elm1,
    available_sets.elm2,
    available_sets.elm3,
    values1.value + values2.value + values3.value
      + ifnull(sum(enabled_single_coupons.value), 0)
      - available_sets.value
      as value_without_set_coupons,     -- セット用クーポン抜きの合計金額
    count(enabled_single_coupons.value)
      as coupon_num_without_set_coupons -- 単品の場合に使用するクーポンの枚数

    from available_sets
      inner join ordered_items as values1 on (available_sets.elm1 = values1.id)
      inner join ordered_items as values2 on (available_sets.elm2 = values2.id)
      inner join ordered_items as values3 on (available_sets.elm3 = values3.id)
      left  join enabled_single_coupons on enabled_single_coupons.target_id in (elm1, elm2, elm3)
    group by
      available_sets.elm1, available_sets.elm2, available_sets.elm3
)

select
  sets_without_set_coupons.id,
  sets_without_set_coupons.elm1,
  sets_without_set_coupons.elm2,
  sets_without_set_coupons.elm3,
  -- セットを適用することで何円安くなるか
  sets_without_set_coupons.value_without_set_coupons - ifnull(enabled_set_coupons.value, 0),
  -- 使用するクーポンが何枚減るか
  sets_without_set_coupons.coupon_num_without_set_coupons - count(enabled_set_coupons.value)

  from sets_without_set_coupons
    left join enabled_set_coupons on enabled_set_coupons.target_id = sets_without_set_coupons.id

  group by                      -- count でまとめない
    sets_without_set_coupons.elm1, sets_without_set_coupons.elm2, sets_without_set_coupons.elm3
;
SQL

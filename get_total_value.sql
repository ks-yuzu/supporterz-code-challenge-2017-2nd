<<"SQL" # Perl 側でプレースホルダを埋め込むためにヒアドキュメントとして扱う
with
enabled_coupons as (
  select * from coupons where id in ($coupon_placeholders)
)

select -- ID, クーポン適用単価, 有効クーポンID
  items.id,
  items.value + ifnull(enabled_coupons.value, 0),
  enabled_coupons.id

  from items
    left join enabled_coupons on (items.id = enabled_coupons.target_id)

  where items.id in ($order_placeholders)
;
SQL

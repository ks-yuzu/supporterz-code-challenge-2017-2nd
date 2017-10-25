-- セット扱いにしたらどれだけ安くなるか
with set_id as (
  select id from sets where elm1='104' and elm2='202' and elm3='308'
)
select
  + (select value from items where id='104')
  + (select value from items where id='202')
  + (select value from items where id='308')
  + ifnull( (select value from coupons where id='C001' and target_id in('104', '202', '308')), 0)
  + ifnull( (select value from coupons where id='C004' and target_id in('104', '202', '308')), 0)
  + ifnull( (select value from coupons where id='C006' and target_id in('104', '202', '308')), 0)
  - ifnull( (select value from items   where id=(select id from set_id)), 0)
  - ifnull( (select value from coupons where id='C001' and target_id=(select id from set_id)), 0)
  - ifnull( (select value from coupons where id='C004' and target_id=(select id from set_id)), 0)
  - ifnull( (select value from coupons where id='C006' and target_id=(select id from set_id)), 0)
;

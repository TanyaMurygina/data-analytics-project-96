--Сколько у нас пользователей заходят на сайт?
select
    to_char(visit_date, 'MONTH') as visits_month,
    count(distinct visitor_id) as count_visitors
from sessions
group by visits_month;

--Какие каналы их приводят на сайт? в разрезе дней недели.
with tab as (
    select
        s.source,
        extract(isodow from s.visit_date) as num_day,
        to_char(s.visit_date, 'day') as day_of_week,
        count(distinct s.visitor_id) as count_visitors
    from sessions as s
    group by s.source, num_day, day_of_week
    order by num_day, s.source
)

select
    t.source,
    t.day_of_week,
    t.count_visitors
from tab as t;

--Сколько лидов к нам приходят?
select
    to_char(created_at, 'MONTH') as leads_month,
    count(distinct lead_id) as leads_count
from leads
group by leads_month;

--Какая конверсия из клика в лид? А из лида в оплату?
select
    s.source, --s.medium, s.campaign,
    count(s.visitor_id) as visitors_count,
    count(l.lead_id) as leads_count,
    count(l.lead_id) filter (where l.status_id = 142) as purchases_count,
    sum(l.amount) as revenue
from sessions as s left join leads as l
    on s.visitor_id = l.visitor_id
where s.source in ('vk', 'yandex')
group by s.source;--, s.medium, s.campaign;

--Сколько мы тратим по разным каналам в динамике? 
(select
    va.utm_source,
    extract(week from va.campaign_date) as week_cost,
    sum(va.daily_spent) as total_cost
from vk_ads as va
group by
    week_cost, va.utm_source
order by week_cost)
union all
(select
    ya.utm_source,
    extract(week from ya.campaign_date) as week_cost,
    sum(ya.daily_spent) as total_cost
from ya_ads as ya
group by
    week_cost, ya.utm_source
order by week_cost);

--Окупаются ли каналы? Расчет метрик
with revenue_source as (
    select
        s.source as utm_source,
        --utm_medium,
        --utm_campaign,
        sum(l.amount) as revenue,
        count(s.visitor_id) as visitors_count,
        count(l.lead_id) as leads_count,
        count(l.lead_id) filter (where l.status_id = 142) as purchases_count
    from
        sessions as s
    left join leads as l
        on s.visitor_id = l.visitor_id
    group by utm_source
),

cost_campaign as ((select
    va.utm_source,
    sum(va.daily_spent) as total_cost
    --va.utm_medium,
    --va.utm_campaign
from vk_ads as va
group by va.utm_source)
union all
(select
    ya.utm_source,
    sum(ya.daily_spent) as total_cost
    --ya.utm_medium,
    --ya.utm_campaign
from ya_ads as ya
group by ya.utm_source)
)

select
    rs.utm_source,
    cc.total_cost,
    rs.revenue,
    cc.total_cost / rs.visitors_count as cpu,
    cc.total_cost / rs.leads_count as cpl,
    cc.total_cost / rs.purchases_count as cppu,
    round(
        (
            (rs.revenue::numeric - cc.total_cost::numeric)
            / nullif(cc.total_cost::numeric, 0)
        )
        * 100.0,
        2
    ) as roi
from revenue_source as rs inner join cost_campaign as cc
    on rs.utm_source = cc.utm_source
where rs.utm_source in ('vk', 'yandex')
order by
    rs.revenue desc nulls last,
    rs.utm_source asc;

--За сколько дней с момента перехода по рекламе закрывается 90% лидов
with tab_leads as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number() over (
            partition by s.visitor_id
            order by s.visit_date desc
        ) as r_number
    from
        sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
)

select
    utm_source,
    utm_medium,
    percentile_disc(0.90) within group (
        order by date_part('day', created_at - visit_date)
    ) as days_leads
from tab_leads
group by utm_source, utm_medium
order by days_leads desc nulls last;

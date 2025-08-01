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
        sessions
            as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where medium != 'organic'
),

vitrina1 as (
    select
        visitor_id,
        utm_source,
        utm_medium,
        utm_campaign,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id,
        date_trunc('day', visit_date) as visit_date
    from tab_leads
    where r_number = 1
    order by
        amount desc nulls last,
        visit_date asc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
),

agreg as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date_trunc('day', visit_date) as visit_date,
        count(visitor_id) as visitors_count,
        count(lead_id) as leads_count,
        count(lead_id) filter (where status_id = 142) as purchases_count,
        sum(amount) as revenue
    from vitrina1
    group by visit_date, utm_source, utm_medium, utm_campaign
),

cost_campaign as ((select
    va.campaign_date,
    sum(va.daily_spent) as total_cost,
    va.utm_source,
    va.utm_medium,
    va.utm_campaign
from vk_ads as va
group by
    va.campaign_date, va.utm_source,
    va.utm_medium,
    va.utm_campaign
order by va.campaign_date)
union all
(select
    ya.campaign_date,
    sum(ya.daily_spent) as total_cost,
    ya.utm_source,
    ya.utm_medium,
    ya.utm_campaign
from ya_ads as ya
group by
    ya.campaign_date, ya.utm_source,
    ya.utm_medium,
    ya.utm_campaign
order by ya.campaign_date)
)

select
    CAST(a.visit_date AS DATE) as visit_date,
    a.visitors_count,
    a.utm_source,
    a.utm_medium,
    a.utm_campaign,
    cc.total_cost,
    a.leads_count,
    a.purchases_count,
    a.revenue
from agreg as a inner join cost_campaign as cc
    on
        a.visit_date = cc.campaign_date and a.utm_source = cc.utm_source
        and a.utm_medium = cc.utm_medium
        and a.utm_campaign = cc.utm_campaign
order by
    a.revenue desc nulls last,
    a.visit_date asc,
    a.visitors_count desc,
    a.utm_source asc,
    a.utm_medium asc,
    a.utm_campaign asc;

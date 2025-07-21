with sessions_paid as (
    select
        *,
        case
            when medium != 'organic' then 0
            else 1
        end as paid_click
    from sessions
    where medium != 'organic'
),

tab_leads as (
    select
        sp.visitor_id,
        sp.visit_date,
        sp.source as utm_source,
        sp.medium as utm_medium,
        sp.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number() over (
            partition by sp.visitor_id
            order by sp.paid_click desc, sp.visit_date desc
        ) as r_number
    from
        sessions_paid
            as sp
    left join leads as l
        on
            sp.visitor_id = l.visitor_id
            and sp.visit_date <= l.created_at
)

select
    visitor_id,
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    lead_id,
    created_at,
    amount,
    closing_reason,
    status_id
from tab_leads
where r_number = 1
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc;

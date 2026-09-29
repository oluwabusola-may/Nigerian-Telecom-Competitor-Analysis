#Renaming column name
ALTER TABLE	internet RENAME COLUMN `ï»¿S/N` TO `S/N`;
ALTER TABLE porting RENAME COLUMN `ï»¿Year` TO `Year`;
ALTER TABLE porting RENAME COLUMN `Port Type` TO `Port_type`;
ALTER TABLE voice RENAME COLUMN `ï»¿Year` TO `Year`;
ALTER TABLE voice RENAME COLUMN `Service type` TO `Service_type`;
ALTER TABLE voice RENAME COLUMN `Quater` TO `Quarter`;

-- 1. Market share (%) by operator, per quarter (voice)
SELECT
    Year, Quarter, Operator,
    SUM(Subscriptions) AS Operator_Subs,
    ROUND(100.0 * SUM(Subscriptions) / SUM(SUM(Subscriptions)) OVER (PARTITION BY Year, Quarter), 2) AS Market_Share_Pct
FROM voice
WHERE Service_type = 'Voice'
GROUP BY Year, Quarter, Operator
ORDER BY Year, Quarter, Market_Share_Pct DESC;

-- 2. Operator with biggest share gain, Q2 2024 -> Q4 2025
WITH Share AS (
    SELECT Year, Quarter, Operator,
        100.0 * SUM(Subscriptions) / SUM(SUM(Subscriptions)) OVER (PARTITION BY Year, Quarter) AS Market_Share_Pct
    FROM voice
    WHERE Service_type = 'Voice'
    GROUP BY Year, Quarter, Operator
),
First_Last AS (
    SELECT Operator,
        MAX(CASE WHEN Year = 2024 AND Quarter = 2 THEN Market_Share_Pct END) AS Share_Start,
        MAX(CASE WHEN Year = 2025 AND Quarter = 4 THEN Market_Share_Pct END) AS Share_End
    FROM Share
    GROUP BY Operator
)
SELECT Operator, Share_Start, Share_End,
    ROUND(Share_End - Share_Start, 2) AS Share_Change_Pts
FROM First_Last
ORDER BY Share_Change_Pts DESC;

-- 3. Dominated states (>50%) vs contested states (no operator >35%), most recent quarter
WITH Share AS (
    SELECT State, Operator,
        100.0 * Subscriptions / SUM(Subscriptions) OVER (PARTITION BY State) AS State_Share_Pct
    FROM voice
    WHERE Service_type = 'Voice' AND Year = 2025 AND Quarter = 4
),
State_Max AS (
    SELECT State, MAX(State_Share_Pct) AS Top_Share
    FROM Share
    GROUP BY State
)
SELECT
    s.State, s.Operator, ROUND(s.State_Share_Pct, 2) AS Share_Pct,
    CASE
        WHEN sm.Top_Share > 50 THEN 'Dominated'
        WHEN sm.Top_Share <= 35 THEN 'Contested'
        ELSE 'Competitive'
    END AS Market_Type
FROM Share s
JOIN State_Max sm ON s.State = sm.State AND s.State_Share_Pct = sm.Top_Share
ORDER BY sm.Top_Share DESC;


-- 4. Operator strength: internet vs voice share comparison, most recent quarter
WITH Combined AS (
    SELECT Operator, Subscriptions, 'Voice' AS Svc FROM voice WHERE Service_type = 'Voice' AND Year = 2025 AND Quarter = 4
    UNION ALL
    SELECT Operator, Subscriptions, 'Internet' AS Svc FROM internet WHERE Service_type = 'Internet' AND Year = 2025 AND Quarter = 4
),
Totals AS (
    SELECT Operator, Svc, SUM(Subscriptions) AS Subs
    FROM Combined
    GROUP BY Operator, Svc
),
Shares AS (
    SELECT Operator, Svc,
        100.0 * Subs / SUM(Subs) OVER (PARTITION BY Svc) AS Share_Pct
    FROM Totals
)
SELECT
    v.Operator,
    ROUND(v.Share_Pct, 2) AS Voice_Share_Pct,
    ROUND(i.Share_Pct, 2) AS Internet_Share_Pct,
    ROUND(i.Share_Pct - v.Share_Pct, 2) AS Internet_Minus_Voice
FROM Shares v
JOIN Shares i ON v.Operator = i.Operator AND v.Svc = 'Voice' AND i.Svc = 'Internet'
ORDER BY Internet_Minus_Voice DESC;

-- 5. Most volatile QoQ growth by operator (voice)
WITH Q AS (
    SELECT Year, Quarter, Operator, SUM(Subscriptions) AS Subs
    FROM voice
    WHERE Service_type = 'Voice'
    GROUP BY Year, Quarter, Operator
),
Growth AS (
    SELECT Year, Quarter, Operator, Subs,
        LAG(Subs) OVER (PARTITION BY Operator ORDER BY Year, Quarter) AS Prev_Subs
    FROM Q
)
SELECT Operator,
    ROUND(STDDEV(100.0 * (Subs - Prev_Subs) / NULLIF(Prev_Subs, 0)), 2) AS QoQ_Growth_Volatility
FROM Growth
WHERE Prev_Subs IS NOT NULL
GROUP BY Operator
ORDER BY QoQ_Growth_Volatility DESC;

-- 6. Net porting flow by operator, per quarter
SELECT
    Year, Quarter, Operator,
    SUM(CASE WHEN Port_Type = 'PORT IN' THEN Count ELSE 0 END) AS Port_In,
    SUM(CASE WHEN Port_Type = 'PORT OUT' THEN Count ELSE 0 END) AS Port_Out,
    SUM(CASE WHEN Port_Type = 'PORT IN' THEN Count ELSE -Count END) AS Net_Flow
FROM porting
GROUP BY Year, Quarter, Operator
ORDER BY Year, Quarter, Net_Flow;

-- 7. Worst cumulative net porting loss, all quarters
SELECT
    Operator,
    SUM(CASE WHEN Port_Type = 'PORT IN' THEN Count ELSE -Count END) AS Cumulative_Net_Flow
FROM porting
GROUP BY Operator
ORDER BY Cumulative_Net_Flow ASC;

-- 8. Does porting loss predict next-quarter share decline?
WITH Net_Port AS (
    SELECT Year, Quarter, Operator,
        SUM(CASE WHEN Port_Type = 'PORT IN' THEN Count ELSE -Count END) AS Net_Flow
    FROM porting
    GROUP BY Year, Quarter, Operator
),
Share AS (
    SELECT Year, Quarter, Operator,
        100.0 * SUM(Subscriptions) / SUM(SUM(Subscriptions)) OVER (PARTITION BY Year, Quarter) AS Market_Share_Pct
    FROM voice
    WHERE Service_type = 'Voice'
    GROUP BY Year, Quarter, Operator
),
Share_Change AS (
    SELECT Year, Quarter, Operator, Market_Share_Pct,
        LEAD(Market_Share_Pct) OVER (PARTITION BY Operator ORDER BY Year, Quarter) - Market_Share_Pct AS Next_Q_Share_Change
    FROM Share
)
SELECT
    np.Year, np.Quarter, np.Operator, np.Net_Flow,
    ROUND(sc.Next_Q_Share_Change, 3) AS Next_Quarter_Share_Change_Pts
FROM Net_Port np
JOIN Share_Change sc ON np.Year = sc.Year AND np.Quarter = sc.Quarter AND np.Operator = sc.Operator
WHERE sc.Next_Q_Share_Change IS NOT NULL
ORDER BY np.Year, np.Quarter, np.Net_Flow;

-- 9. Share of all port-ins won by each operator, per quarter
SELECT
    Year, Quarter, Operator,
    SUM(Count) AS Port_Ins,
    ROUND(100.0 * SUM(Count) / SUM(SUM(Count)) OVER (PARTITION BY Year, Quarter), 2) AS Pct_Of_All_Port_Ins
FROM porting
WHERE Port_Type = 'PORT IN'
GROUP BY Year, Quarter, Operator
ORDER BY Year, Quarter, Pct_Of_All_Port_Ins DESC;


*Competitive Battlegrounds (Regional)*

-- 10. Fastest-gaining challenger states (non-MTN), YoY
WITH YoY AS (
    SELECT State, Operator, Year, Quarter, SUM(Subscriptions) AS Subs
    FROM voice
    WHERE Service_type = 'Voice' AND Operator <> 'MTN'
    GROUP BY State, Operator, Year, Quarter
),
Yoy_Delta AS (
    SELECT State, Operator, Year, Quarter, Subs,
        Subs - LAG(Subs, 4) OVER (PARTITION BY State, Operator ORDER BY Year, Quarter) AS YoY_Change
    FROM YoY
)
SELECT State, Operator, Year, Quarter, YoY_Change
FROM Yoy_Delta
WHERE YoY_Change IS NOT NULL
ORDER BY YoY_Change DESC
LIMIT 20;

-- 11. Does a challenger's national share gain line up with them winning net ports nationally?
WITH National_Share AS (
    SELECT Operator, Year, Quarter,
        100.0 * SUM(Subscriptions) / SUM(SUM(Subscriptions)) OVER (PARTITION BY Year, Quarter) AS National_Share_Pct
    FROM voice
    WHERE Service_type = 'Voice'
    GROUP BY Operator, Year, Quarter
),
Share_Delta AS (
    SELECT Operator, Year, Quarter, National_Share_Pct,
        National_Share_Pct - LAG(National_Share_Pct) OVER (PARTITION BY Operator ORDER BY Year, Quarter) AS Share_Change_Pts
    FROM National_Share
),
Port_Flow AS (
    SELECT Operator, Year, Quarter,
        SUM(CASE WHEN Port_Type = 'P' THEN Count ELSE -Count END) AS Net_Flow
    FROM porting
    GROUP BY Operator, Year, Quarter
)
SELECT
    sd.Operator, sd.Year, sd.Quarter,
    ROUND(sd.Share_Change_Pts, 2) AS Share_Change_Pts,
    pf.Net_Flow
FROM Share_Delta sd
JOIN Port_Flow pf ON sd.Operator = pf.Operator AND sd.Year = pf.Year AND sd.Quarter = pf.Quarter
WHERE sd.Share_Change_Pts IS NOT NULL
ORDER BY sd.Share_Change_Pts DESC;


-- 12. Most competitively contested zone (Herfindahl Index), most recent quarter, voice
WITH Zone_Share AS (
    SELECT Zone, Operator,
        100.0 * SUM(Subscriptions) / SUM(SUM(Subscriptions)) OVER (PARTITION BY Zone) AS Share_Pct
    FROM voice
    WHERE Service_type = 'Voice' AND Year = 2025 AND Quarter = 4
    GROUP BY Zone, Operator
)
SELECT Zone,
    ROUND(SUM(POWER(Share_Pct / 100.0, 2)), 4) AS Herfindahl_Index
FROM Zone_Share
GROUP BY Zone
ORDER BY Herfindahl_Index ASC;

**Validation**

-- 13a. Voice table validation
SELECT Year, Quarter, SUM(Subscriptions) AS Calculated_Total
FROM voice
WHERE Service_type = 'Voice'
GROUP BY Year, Quarter
ORDER BY Year, Quarter;

-- 13b. Internet table validation
SELECT Year, Quarter, SUM(Subscriptions) AS Calculated_Total
FROM internet
WHERE Service_type = 'Internet'
GROUP BY Year, Quarter
ORDER BY Year, Quarter;

-- 14. States with the largest gap between voice and internet penetration
WITH Voice_State AS (
    SELECT State, SUM(Subscriptions) AS Voice_Subs
    FROM voice
    WHERE Service_type = 'Voice' AND Year = 2025 AND Quarter = 4
    GROUP BY State
),
Internet_State AS (
    SELECT State, SUM(Subscriptions) AS Internet_Subs
    FROM internet
    WHERE Service_type = 'Internet' AND Year = 2025 AND Quarter = 4
    GROUP BY State
)
SELECT
    v.State,
    v.Voice_Subs,
    i.Internet_Subs,
    ROUND(100.0 * i.Internet_Subs / v.Voice_Subs, 2) AS Internet_As_Pct_Of_Voice,
    v.Voice_Subs - i.Internet_Subs AS Penetration_Gap
FROM Voice_State v
JOIN Internet_State i ON v.State = i.State
ORDER BY Penetration_Gap DESC;



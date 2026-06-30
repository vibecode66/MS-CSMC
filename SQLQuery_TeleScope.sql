--Average active time per session (active specific user time,  active specific user sessions)
-- Where session count is Distinct combinations of WorkSessionId and ToolName

WITH SessionToolTable AS (
    SELECT DISTINCT
        ws.UserName,
        ta.WorkSessionId,
        ta.ToolName
    FROM ATT.ToolActivities ta
    INNER JOIN ATT.WorkSessions ws
        ON ta.WorkSessionId = ws.Id
    WHERE ta.WorkSessionId IS NOT NULL
      AND ta.ToolName IS NOT NULL
),
ActiveTimeByUser AS (
    SELECT
        ws.UserName,
        SUM(
            CASE
                WHEN ta.IsActive = 1
                     AND ta.StartTimeUtc IS NOT NULL
                     AND ta.EndTimeUtc IS NOT NULL
                THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc)
                ELSE 0
            END
        ) AS TotalActiveSeconds
    FROM ATT.ToolActivities ta
    INNER JOIN ATT.WorkSessions ws
        ON ta.WorkSessionId = ws.Id
    GROUP BY ws.UserName
),
SessionToolCountByUser AS (
    SELECT
        UserName,
        COUNT(*) AS TotalCount
    FROM SessionToolTable
    GROUP BY UserName
)
SELECT
    a.UserName,
    a.TotalActiveSeconds,
    c.TotalCount,
    ROUND(a.TotalActiveSeconds * 1.0 / NULLIF(c.TotalCount * 60, 0), 2) AS [pbi_ACTIVE TIME PER SESSION PER USER]
FROM ActiveTimeByUser a
INNER JOIN SessionToolCountByUser c
    ON a.UserName = c.UserName
ORDER BY a.UserName;

---------------------


--To get active time for each user
SELECT
    ws.UserName,
    SUM(
        CASE
            WHEN ta.IsActive = 1
                 AND ta.StartTimeUtc IS NOT NULL
                 AND ta.EndTimeUtc IS NOT NULL
            THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc)
            ELSE 0
        END
    ) AS TotalActiveSeconds,
    CAST(
        SUM(
            CASE
                WHEN ta.IsActive = 1
                     AND ta.StartTimeUtc IS NOT NULL
                     AND ta.EndTimeUtc IS NOT NULL
                THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc)
                ELSE 0
            END
        ) / 3600.0 AS DECIMAL(18, 2)
    ) AS TotalActiveHours
FROM ATT.WorkSessions ws
LEFT JOIN ATT.ToolActivities ta
    ON ws.Id = ta.WorkSessionId
GROUP BY ws.UserName


-- distinct session of count for each user
SELECT
    ws.UserName,
    COUNT(DISTINCT ws.Id) AS DistinctWorkSessionCount
FROM ATT.WorkSessions ws
GROUP BY ws.UserName

--CounDistinct Worksession ids for user Prasad

SELECT COUNT(DISTINCT ta.WorkSessionId) AS DistinctSessionCount
FROM ATT.ToolActivities ta
INNER JOIN ATT.WorkSessions ws
    ON ta.WorkSessionId = ws.Id
WHERE ws.UserName = 'prmummir';


-- View the Tool Activities Table
SELECT * FROM ATT.ToolActivities

-- View the Work Session Table
SELECT * FROM ATT.WorkSessions

-- start and end time for a casenumber
SELECT
    MIN(StartTimeUtc) AS StartTimeUtc,
    MAX(EndTimeUtc)   AS EndTimeUtc
FROM ATT.WorkSessions
WHERE CaseNumber = '5-0000014209300';

--USER ACTIVE AND IDLE TIME FOR A SPECIFIC USER Between Specific dates
SELECT
    ws.UserName,
    SUM(
        CASE 
            WHEN ta.IsActive = 1 THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc)
            ELSE 0
        END
    ) / 60.0 AS ActiveTime_Minutes,

    SUM(
        CASE 
            WHEN ta.IsActive = 0 THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc)
            ELSE 0
        END
    ) / 60.0 AS IdleTime_Minutes,

    SUM(
        CASE 
            WHEN ta.IsActive = 1 THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc)
            ELSE 0
        END
    ) / 3600.0 AS ActiveTime_Hours,

    SUM(
        CASE 
            WHEN ta.IsActive = 0 THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc)
            ELSE 0
        END
    ) / 3600.0 AS IdleTime_Hours

FROM ATT.WorkSessions ws
INNER JOIN ATT.ToolActivities ta
    ON ws.Id = ta.WorkSessionId
WHERE ws.UserName = 'prmummir'
  AND ta.StartTimeUtc >= '2026-05-19'
  AND ta.StartTimeUtc <  '2026-05-20'
  AND ta.StartTimeUtc IS NOT NULL
  AND ta.EndTimeUtc IS NOT NULL
GROUP BY
    ws.UserName;


-- What are the casenumbers worked by user 'prmummir' between dates 05-10-2026 to 05-10-2026

    SELECT DISTINCT
    ws.UserName,
    ws.CaseNumber
FROM ATT.WorkSessions ws
INNER JOIN ATT.ToolActivities ta
    ON ws.Id = ta.WorkSessionId
WHERE ws.UserName = 'prmummir'
  AND ws.CaseNumber IS NOT NULL
  AND ta.StartTimeUtc >= '2026-05-10 00:00:00'
  AND ta.StartTimeUtc <  '2026-05-20 00:00:00'
ORDER BY
    ws.CaseNumber;



    --Time for each tool as per the flow at every stage for a given case number
with tool_flow as (
    select 
        b.ToolName,
        b.StartTimeUtc,
        b.EndTimeUtc,
        case 
            when lag(b.ToolName) over (order by b.StartTimeUtc) = b.ToolName 
            then 0 else 1 
        end as change_flag
    from att.WorkSessions a
    inner join att.ToolActivities b
        on a.id = b.WorkSessionId
    where a.CaseNumber = '5-0000014185118'
),
grp as (
    select *,
        sum(change_flag) over (order by StartTimeUtc) as grp_id
    from tool_flow
)
select 
    ToolName,
    min(StartTimeUtc) as StartTimeUtc,
    max(EndTimeUtc) as EndTimeUtc,
    sum(DATEDIFF(SECOND, StartTimeUtc, EndTimeUtc)) / 60.0 as TimeSpent_Minutes
from grp
group by grp_id, ToolName
order by min(StartTimeUtc);


--Cumuative time for each tool in case number = '5-0000014185118
with tool_flow as (
    select 
        b.ToolName,
        b.StartTimeUtc,
        b.EndTimeUtc
    from att.WorkSessions a
    inner join att.ToolActivities b
        on a.id = b.WorkSessionId
    --where a.CaseNumber = '5-0000014185118'
    where a.CaseNumber = '5-0000014209300'
)
select 
    ToolName,
    sum(DATEDIFF(SECOND, StartTimeUtc, EndTimeUtc)) / 60.0 as TotalTime_Minutes
from tool_flow
group by ToolName
order by min(StartTimeUtc);

--How much time is spent on each tool for each use casewith tool_flow as (
    select 
        a.CaseNumber,
        b.ToolName,
        b.StartTimeUtc,
        b.EndTimeUtc
    from att.WorkSessions a
    inner join att.ToolActivities b
        on a.id = b.WorkSessionId
    where a.CaseNumber is not null
)
select 
    CaseNumber,
    ToolName,
    sum(DATEDIFF(SECOND, StartTimeUtc, EndTimeUtc)) / 60.0 as TotalTime_Minutes
from tool_flow
group by 
    CaseNumber,
    ToolName
order by 
    CaseNumber,
    min(StartTimeUtc);



    -- Total Idle time for each user
SELECT
    ws.UserName,
    ROUND(
        SUM(CASE 
                WHEN ta.IsActive = 0 
                     AND ta.StartTimeUtc IS NOT NULL 
                     AND ta.EndTimeUtc IS NOT NULL
                THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc) 
                ELSE 0 
            END
        ) / 3600.0,
        2
    ) AS TotalIdleHours
FROM ATT.ToolActivities ta
INNER JOIN ATT.WorkSessions ws
    ON ta.WorkSessionId = ws.Id
WHERE ws.UserName IS NOT NULL
GROUP BY ws.UserName
ORDER BY TotalIdleHours DESC;



--Overall active and idle time
WITH TimeTotals AS (
    SELECT
        SUM(
            CASE
                WHEN ta.IsActive = 1
                     AND ta.StartTimeUtc IS NOT NULL
                     AND ta.EndTimeUtc IS NOT NULL
                THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc)
                ELSE 0
            END
        ) AS TotalActiveSeconds,

        SUM(
            CASE
                WHEN ta.IsActive = 0
                     AND ta.StartTimeUtc IS NOT NULL
                     AND ta.EndTimeUtc IS NOT NULL
                THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc)
                ELSE 0
            END
        ) AS TotalIdleSeconds
    FROM ATT.ToolActivities ta
    INNER JOIN ATT.WorkSessions ws
        ON ta.WorkSessionId = ws.Id
)
SELECT
    CONCAT(
        TotalActiveSeconds / 3600,
        ' Hours ',
        (TotalActiveSeconds % 3600) / 60,
        ' Minutes'
    ) AS TotalActiveTime,

    CONCAT(
        TotalIdleSeconds / 3600,
        ' Hours ',
        (TotalIdleSeconds % 3600) / 60,
        ' Minutes'
    ) AS TotalIdleTime
FROM TimeTotals;

--Month on Month active and idle time
SELECT
    MONTH(ta.StartTimeUtc) AS MonthNum,

    -- Active Time (in hours)
    SUM(
        CASE 
            WHEN ta.IsActive = 1
                 AND ta.StartTimeUtc IS NOT NULL
                 AND ta.EndTimeUtc IS NOT NULL
            THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc)
            ELSE 0
        END
    ) / 3600.0 AS ActiveHours,

    -- Idle Time (in hours)
    SUM(
        CASE 
            WHEN ta.IsActive = 0
                 AND ta.StartTimeUtc IS NOT NULL
                 AND ta.EndTimeUtc IS NOT NULL
            THEN DATEDIFF(SECOND, ta.StartTimeUtc, ta.EndTimeUtc)
            ELSE 0
        END
    ) / 3600.0 AS IdleHours

FROM ATT.ToolActivities ta
INNER JOIN ATT.WorkSessions ws
    ON ta.WorkSessionId = ws.Id

GROUP BY
    MONTH(ta.StartTimeUtc)

ORDER BY
    MonthNum;
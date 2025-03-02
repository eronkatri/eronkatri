--------1

GO

WITH Income_per_year
AS 
(
SELECT YEAR(o.OrderDate) AS YY
,SUM(l.ExtendedPrice-l.TaxAmount) AS IncomePerYear
,COUNT(DISTINCT MONTH(o.orderdate)) AS NumberOfDistinctMonths
,CAST(ROUND(SUM(l.ExtendedPrice-l.TaxAmount)/COUNT(DISTINCT MONTH(o.orderdate))*12,2) AS MONEY) AS YearlyLinearIncome
FROM Sales.InvoiceLines l JOIN Sales.Invoices i
ON l.InvoiceID=i.InvoiceID
JOIN Sales.Orders o 
ON o.OrderID = i.OrderID
GROUP BY YEAR(o.OrderDate)
)


SELECT *
,(YearlyLinearIncome-LAG(YearlyLinearIncome,1)OVER(ORDER BY YY))/LAG(YearlyLinearIncome,1)OVER(ORDER BY YY)*100 AS GrowthRate
FROM  Income_per_year 



--------2

GO

WITH best_customers
AS 
(
SELECT YEAR(i.InvoiceDate) AS TheYear
,DATEPART(QQ,i.InvoiceDate) AS TheQuarter
,c.CustomerName
,SUM(il.Quantity*il.UnitPrice)AS IncomePerYear
,RANK()OVER(PARTITION BY YEAR(i.InvoiceDate),DATEPART(QQ,i.InvoiceDate) ORDER BY SUM(il.Quantity*il.UnitPrice)DESC) AS DNR
FROM Sales.Customers c JOIN Sales.Invoices i
ON c.CustomerID = i.CustomerID
JOIN Sales.InvoiceLines il
ON il.InvoiceID = i.InvoiceID
GROUP BY  YEAR(i.InvoiceDate)  
,DATEPART(QQ,i.InvoiceDate)
,c.CustomerName
)

SELECT *
FROM best_customers
WHERE DNR<=5



--------3
GO

WITH Top_10_products
AS
(
SELECT i.StockItemID AS StockItemID
,w.StockItemName AS StockItemName
,SUM(i.ExtendedPrice-i.TaxAmount) AS TotalProfit
,ROW_NUMBER()OVER(ORDER BY SUM(i.ExtendedPrice-i.TaxAmount)DESC) AS RN
FROM Sales.InvoiceLines i JOIN Warehouse.StockItems w
ON i.StockItemID = w.StockItemID
GROUP BY i.StockItemID
,w.StockItemName)

SELECT StockItemID
,StockItemName
,TotalProfit
FROM Top_10_products
WHERE RN <=10


----------4

WITH CTE
AS
(
SELECT 
s.StockItemID
,s.StockItemName
,s.UnitPrice
,s.RecommendedRetailPrice
,s.RecommendedRetailPrice-s.UnitPrice AS NominalProductProfit
,DENSE_RANK()OVER(ORDER BY s.RecommendedRetailPrice-s.UnitPrice DESC)AS DNR
FROM Warehouse.StockItems s
)
SELECT ROW_NUMBER()OVER(ORDER BY DNR) AS RN
,*
FROM CTE

---------5 


SELECT CONCAT( ps.SupplierID,' - '+ ps.SupplierName) AS SupplierDetails
,STUFF((SELECT '/,'+ CAST(s.StockItemid AS varchar) +' '+s.StockItemName
FROM Warehouse.StockItems s
WHERE s.SupplierID = ps.SupplierID
FOR XML PATH ('')),1,2,'') AS ProductDetails
FROM Purchasing.Suppliers ps
WHERE ps.SupplierID IN (1,2,4,5,7,10,12 )



--------------6


WITH Top_5
AS
(
SELECT  TOP(5) sc.CustomerID AS CustomerID
,ci.CityName AS CityName
,c.CountryName AS CountryName
,c.Continent AS Continent
,c.Region AS Region
,SUM(il.ExtendedPrice) AS TotalExtendedPrice
FROM Application.Countries c JOIN Application.StateProvinces s
ON c.CountryID = s.CountryID
JOIN Application.Cities ci
ON ci.StateProvinceID = s.StateProvinceID
JOIN Sales.Customers sc
ON sc.DeliveryCityID = ci.CityID
JOIN Sales.Invoices i
ON i.CustomerID=sc.CustomerID
JOIN Sales.InvoiceLines il
ON il.InvoiceID=i.InvoiceID
GROUP BY sc.CustomerID,ci.CityName,c.CountryName,c.Continent,c.Region
ORDER BY TotalExtendedPrice DESC
)

SELECT CustomerID
,CityName
,CountryName
,Continent
,Region
,FORMAT(TotalExtendedPrice,'#,#.00') AS TotalExtendedPrice
FROM Top_5




---------------7


GO


SELECT OrderYear
,REPLACE(OrderMonth,'13','Grand Total')AS OrderMonth
,FORMAT(MonthlyTotal,'#,#.00')AS MonthlyTotal
  ,CASE WHEN OrderMonth='13' 
  THEN FORMAT(MonthlyTotal,'#,#.00')
  ELSE FORMAT(SUM(MonthlyTotal)OVER(PARTITION BY OrderYear ORDER BY OrderMonth),'#,#.00')
  END AS CumulativeTotal
FROM (
    SELECT YEAR(o.OrderDate) AS OrderYear
    ,MONTH(o.OrderDate) AS OrderMonth
    ,SUM(l.UnitPrice*l.Quantity)AS MonthlyTotal
    FROM Sales.InvoiceLines l JOIN Sales.Invoices i
    ON l.InvoiceID=i.InvoiceID
    JOIN Sales.Orders o 
    ON o.OrderID = i.OrderID
    GROUP BY YEAR(o.OrderDate),MONTH(o.OrderDate)
    UNION
    SELECT YEAR(o.OrderDate) AS OrderYear
    ,13 AS OrderMonth
    ,SUM(l.UnitPrice*l.Quantity)OVER(PARTITION BY YEAR(o.OrderDate))AS CumulativeTotal
    FROM Sales.InvoiceLines l JOIN Sales.Invoices i
    ON l.InvoiceID=i.InvoiceID
    JOIN Sales.Orders o 
    ON o.OrderID = i.OrderID) T



-----------8

SELECT mm,[2013],[2014],[2015],[2016]
FROM ( SELECT OrderID
       ,MONTH(OrderDate) AS mm
       ,YEAR(OrderDate) AS yy
       FROM Sales.Orders )t
 PIVOT(COUNT(orderid)FOR yy IN ([2013],[2014],[2015],[2016]))PVT
 ORDER BY mm



 --------------9

WITH CTE1
AS
(
SELECT c.CustomerID,c.CustomerName,o.OrderDate
,LAG(o.OrderDate,1)OVER(PARTITION BY c.CustomerID ORDER BY o.OrderDate) AS PreviousOrderDate
,MAX(o.OrderDate)OVER(PARTITION BY c.CustomerID) AS Maxorder 
FROM Sales.Orders o JOIN Sales.Customers c
ON o.CustomerID=c.CustomerID
)


SELECT CustomerID,CustomerName,OrderDate,PreviousOrderDate
,DATEDIFF(DD,Maxorder,MAX(OrderDate)OVER()) AS DaysSinceLastOrder
,AVG(DATEDIFF(DD,PreviousOrderDate,OrderDate))OVER(PARTITION BY CustomerID) AS AvgDaysBetweenOrders
,IIF(DATEDIFF(DD,Maxorder,MAX(OrderDate)OVER())>AVG(DATEDIFF(DD,PreviousOrderDate,OrderDate))OVER(PARTITION BY CustomerID)*2,'Potential Churn','Active') AS CustomerStatus
FROM CTE1





--------------10 


SELECT  cc.CustomerCategoryName
,COUNT(DISTINCT CASE WHEN c.CustomerName  LIKE ('Tailspin%') THEN 'Tailspin'
WHEN c.CustomerName LIKE ('Wingtip%') THEN 'Wingtip'
ELSE c.CustomerName
END) AS "CustomerCOUNT"
,SUM(COUNT(DISTINCT CASE WHEN c.CustomerName  LIKE ('Tailspin%') THEN 'Tailspin'
WHEN c.CustomerName LIKE ('Wingtip%') THEN 'Wingtip'
ELSE c.CustomerName
END))OVER() AS "TotalCustCount"
,CONCAT(CAST(ROUND(COUNT(DISTINCT CASE WHEN c.CustomerName  LIKE ('Tailspin%') THEN 'Tailspin'
WHEN c.CustomerName LIKE ('Wingtip%') THEN 'Wingtip'
ELSE c.CustomerName
END)/263.*100,2) AS MONEY),'%') AS "DistributionFactor"
FROM Sales.CustomerCategories cc JOIN Sales.Customers c 
ON cc.CustomerCategoryID=c.CustomerCategoryID
GROUP BY  cc.CustomerCategoryName
ORDER BY cc.CustomerCategoryName







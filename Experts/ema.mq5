//+------------------------------------------------------------------+
//| Expert advisor: TRM EA                                           |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Indicators\Trend.mqh>

input int      EMA_Periods = 120;
input double   EMA_Exp = 2.0;
input int      DirMultiplier = 2;

double         EMA_Buffer[];

CTrade         trade;
CIndicatorEMA  EMA_Indicator;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, EMA_Buffer);
   EMA_Indicator.SetPeriod(EMA_Periods);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   double currentPrice = Close[0];
   double previousEMA = EMA_Buffer[1];
   double currentEMA = EMA_Calc(currentPrice, previousEMA);

   EMA_Buffer[0] = currentEMA;

   int trendDir = TrendDirection(0, currentPrice, currentEMA);
   ExecuteTrade(trendDir);
  }

//+------------------------------------------------------------------+
//| EMA Calculation                                                  |
//+------------------------------------------------------------------+
double EMA_Calc(double price, double previousEMA)
  {
   double exp = 2.0 / (EMA_Periods + 1);
   return price * exp + previousEMA * (1 - exp);
  }

//+------------------------------------------------------------------+
//| Determine Trend Direction                                        |
//+------------------------------------------------------------------+
int TrendDirection(int index, double price, double ema)
  {
   int maxVal = EMA_Periods / DirMultiplier;
   bool isUptrend = true;
   bool isDowntrend = true;

   for (int offset = 0; offset <= maxVal; offset++)
     {
      if (price <= ema) isUptrend = false;
      if (price >= ema) isDowntrend = false;
     }

   if (isUptrend) return 1;
   if (isDowntrend) return -1;

   return 0;
  }

//+------------------------------------------------------------------+
//| Execute Trade Based on Trend Direction                           |
//+------------------------------------------------------------------+
void ExecuteTrade(int trendDir)
  {
   // Implement your trade execution logic here
   // This could include checking for existing positions, order placement, etc.
  }

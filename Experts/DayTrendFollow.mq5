
#include <Trade\Trade.mqh>
CTrade trade;

input long MagicNumber = 8;      // magic number
input int OpenHour = 3;          // Trade open hour
input int CloseHour = 21;        // Trade close hour
input double Lots = 1.0;         // Risk size
 ENUM_MA_METHOD MA_Method = MODE_EMA;  // Moving Average method 
 ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE; // Price applied to MA 
input int MA_Period = 240;        // Moving Average period (0 = off)
input int changePeriod = 5;     // change period
input bool BuyTrades = true; // Take buys
input bool SellTrades = true; // Take sells

MqlTick tick;
MqlDateTime time;
string currentSymbol = Symbol();
double ma_value;
int lastMaDirection;

int OnInit()
  {
   trade.SetExpertMagicNumber(MagicNumber);
   Print("EA Initialized");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   Print("EA Deinitialized");
  }

void OnTick()
{
   SymbolInfoTick(currentSymbol, tick);
   tick.last = iClose(currentSymbol,PERIOD_CURRENT,0);
   TimeToStruct(TimeCurrent(), time);
   int current_hour = time.hour;
   int position_count = PositionCount();
   //MA();
   if(MA_Period>0)MovingAverage();
   Comment(time.hour," : ",time.min," : ",time.sec,"\n",tick.last,"\n",AverageTrueRange(),"\n",Volume());
   
   if (current_hour >= OpenHour && current_hour < CloseHour){
      
      if ((lastDirection == 0 && MA_Period>0) || position_count > 0) return;
      double current_price = tick.last;
      if (current_price > ma_value && BuyTrades && (lastDirection > 0||MA_Period==0)) trade.Buy(Volume());
      if (current_price < ma_value && SellTrades && (lastDirection < 0||MA_Period==0)) trade.Sell(Volume());
   } else
     {
        CloseAll();
     }
}

int barsTotal;
int lastDirection;
void MovingAverage()
{
  int maHandle = iMA(currentSymbol, PERIOD_D1, MA_Period, 0, MA_Method, MA_Price);
  double maBuffer[];
  ArraySetAsSeries(maBuffer, true);
  int bars = iBars(currentSymbol, PERIOD_D1);
  CopyBuffer(maHandle, 0, 0, changePeriod*2, maBuffer);
  ma_value = NormalizeDouble(maBuffer[0],Digits());
  if (barsTotal >= bars) return;
  barsTotal = bars;
  for (int i=0;i<changePeriod;i++) {
     double close = iClose(currentSymbol,PERIOD_D1,i);
     double ma = maBuffer[i];
     int direction = close > ma ? 1 : close < ma ? -1 : 0;
     if (i == 0) lastDirection = direction;
     if (direction != lastDirection) lastDirection = 0;
    
  datetime start_time = iTime(currentSymbol,PERIOD_D1,i);
  datetime end_time = start_time + PeriodSeconds(PERIOD_D1);
  ObjectCreate(0, "Ma " + (string)start_time, OBJ_TREND, 0, start_time, maBuffer[i+1], end_time, ma);
  ObjectSetInteger(0, "Ma " + (string)start_time, OBJPROP_STYLE, STYLE_SOLID);
  ObjectSetInteger(0, "Ma " + (string)start_time, OBJPROP_WIDTH, 4);
  ObjectSetInteger(0, "Ma " + (string)start_time, OBJPROP_BACK, true);
  ObjectSetInteger(0, "Ma " + (string)start_time, OBJPROP_COLOR, lastDirection == 1 ? clrGreen : lastDirection == -1 ? clrRed : clrBlue);
  }
}

int PositionCount()
{
  int count = 0;
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (!PositionSelectByTicket(ticket))
      continue;
    if (PositionGetString(POSITION_SYMBOL) != currentSymbol || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
      continue;
    count++;
  }
  return count;
}

void CloseAll()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0)
        {
            if (PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetString(POSITION_SYMBOL) != currentSymbol)
                continue;
            trade.PositionClose(ticket);
        }
    }
}

double AverageTrueRange()
{
  int atrHandle = iATR(currentSymbol, PERIOD_D1, 20);
  double atrBuffer[];
  ArraySetAsSeries(atrBuffer, true);
  CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
  return atrBuffer[0];
}

  double minVol = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MIN);
  double maxVol = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MAX);
  double tickSize = SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE);
  double tickValue = SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_VALUE);  
  double lotStep = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_STEP);
double Volume()
{
  double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * Lots * 0.01;
  double moneyLotStep = AverageTrueRange() / tickSize * tickValue * lotStep;
  double lots = MathRound(riskMoney / moneyLotStep) * lotStep;
  if (lots < minVol || lots == NULL) lots = minVol;
  else if (lots > maxVol) lots = maxVol;
  return lots;
}


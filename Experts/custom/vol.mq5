//+------------------------------------------------------------------+
//|                                                           bp.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| imports                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;
//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input int startHour = 5; // start hour
input int endHour = 19; // end hour
input double riskToReward = 2.0; // risk/reward ratio
input double multiplierStop = 3.0; // multiplier sl
input double multiplierVol = 2.0; // multiplier vol
input double lotSizePercentage = 1.0; // percentage risk
input double cover = 1.2; // cover
input double maxLossPercentDay = 0; // max DDD %
input int maxAmountHedges = 0; // max hedges
//+------------------------------------------------------------------+
//| global parameters                                                |
//+------------------------------------------------------------------+
bool isFirstCandle = true;
bool isNewDay = true;
bool isBuy = false;
bool isSell = false;
bool cascade=false;
bool isHedge = false;

double bid = 0.0;
double ask = 0.0;

double entryPrice = 0.0;
double stopPrice = 0.0;
double stopPoints = 0.0;
double profitPoints = 0.0;
double profitPrice = 0.0;
double lotSize = 0.0;

double lotSizeHedgeBuy = 0.0;
double lotSizeHedgeSell = 0.0;

int hedgeAmount = 0;
int maxHedges = 0;

double equitySinceOpen = 1;
double maxDrawdownSinceOpen = 1;

double dddp = 0.0;
double periodVal = 7200;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {  
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0, "Vline");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(hedgeAmount > maxHedges) maxHedges = hedgeAmount;
   
   dddp = maxDrawdownSinceOpen/equitySinceOpen * 100;
   string plot = "\nE: "+NormalizeDouble(entryPrice,Digits()) +"\nS: "+NormalizeDouble(stopPrice,Digits()) +"  p: "+NormalizeDouble(stopPoints*100000,Digits()) +"\nP: "+NormalizeDouble(profitPrice,Digits()) +"  p: "+NormalizeDouble(profitPoints*100000,Digits()) +"\n\nlots: "+lotSize +"\nhedges: "+hedgeAmount +"\ndddp: "+dddp;
   Comment( plot+"\natr: "+NormalizeDouble(atrValue(periodVal)*multiplierStop,Digits()));
   
   MqlTick Latest_Price; 
   SymbolInfoTick(Symbol() ,Latest_Price);
   bid = Latest_Price.bid;   
   ask = Latest_Price.ask;  
   
   
   if(IsNewCandle(PERIOD_M1)) isFirstCandle = true;
   
   if(!WithinTradingHours(startHour,endHour)) return;
   Vline();
   
   if(PositionsTotal() == 0 && CheckMaxDDThreshold(maxLossPercentDay) && isFirstCandle && !isHedge && !cascade && IsCurrentVolumeHigher()){
      if(DirectionLong()){
         entryPrice = ask;
         stopPrice = ask - NormalizeDouble(atrValue(periodVal)*multiplierStop,Digits());
         stopPoints = NormalizeDouble(MathAbs(entryPrice - stopPrice),Digits());
         profitPoints = stopPoints * riskToReward;
         profitPrice = entryPrice + profitPoints;
         lotSize = OptimumLotSize(lotSizePercentage, stopPoints);
         lotSizeHedgeBuy = OptimumLotSize(lotSizePercentage, stopPoints);
         SendTrade("buy", lotSize, 0, 0, 0, "spike");
         isFirstCandle=false;
         isBuy=true;
      }
      if(DirectionShort()){
         entryPrice = bid;
         stopPrice = bid + NormalizeDouble(atrValue(periodVal)*multiplierStop,Digits());
         stopPoints = NormalizeDouble(MathAbs(stopPrice - entryPrice),Digits());
         profitPoints = stopPoints * riskToReward;
         profitPrice = entryPrice - profitPoints;
         lotSize = OptimumLotSize(lotSizePercentage, stopPoints);
         lotSizeHedgeSell = OptimumLotSize(lotSizePercentage, stopPoints);
         SendTrade("sell", lotSize, 0, 0, 0, "spike");
         isFirstCandle=false;
         isSell=true;
      }
   }
   if(isBuy && ask >= profitPrice && !isHedge){
         entryPrice = ask;
         stopPrice = ask - stopPoints;
         profitPrice = ask + profitPoints;
         SendTrade("buy", lotSize, 0, 0, 0, "cascade");
         isBuy=true;
         cascade=true;
     }
   if(isSell && bid <= profitPrice && !isHedge){
         entryPrice = bid;
         stopPrice = bid + stopPoints;
         profitPrice = bid - profitPoints;
         SendTrade("sell", lotSize, 0, 0, 0, "cascade");
         isSell=true;
         cascade=true;
     }
   if((isBuy && bid <= stopPrice) || (isSell && ask >= stopPrice)){ 
      isHedge = true;
      if(cascade)
        {
            CloseOlderTrades();
            cascade = false;
        }
   } 
   if (isHedge)
    {
           // Implement the Zone Recovery Strategy
           if (isBuy && bid <= stopPrice)
           {
               lotSize = NormalizeDouble(((riskToReward+1/riskToReward)*(lotSizeHedgeBuy) - (lotSizeHedgeSell))*cover, 2);
               lotSizeHedgeSell += lotSize;
               stopPrice = ask + stopPoints;
               profitPrice = bid - profitPoints;
               isBuy = false;
               isSell = true;
               hedgeAmount += 1;
               if(maxAmountHedges == 0 || hedgeAmount <= maxAmountHedges && CheckMaxDDThreshold(maxLossPercentDay)){
                  SendTrade("sell", lotSize, 0, 0, 0, "hedge");
               }  
               else{
                  CloseAllTrades();
                 }
           }
           else if (isSell && ask >= stopPrice)
           {
               lotSize = NormalizeDouble(((riskToReward+1/riskToReward)*(lotSizeHedgeSell) - (lotSizeHedgeBuy))*cover, 2);
               lotSizeHedgeBuy += lotSize;
               stopPrice = bid - stopPoints;
               profitPrice = ask + profitPoints;
               isBuy = true;
               isSell = false;
               hedgeAmount += 1;
               if(maxAmountHedges == 0 || hedgeAmount <= maxAmountHedges && CheckMaxDDThreshold(maxLossPercentDay)){
                  SendTrade("buy", lotSize, 0, 0, 0, "hedge");
               }
               else{
                  CloseAllTrades();
               }
           }
      }
      // Implement the take profit logic
      if ((isBuy && bid >= profitPrice) || (isSell && ask <= profitPrice))
      {
         // Take profit is hit, close all trades
         CloseAllTrades();
      }
}
//+------------------------------------------------------------------+
//| check max dd                                                     |
//+------------------------------------------------------------------+
bool CheckMaxDDThreshold(double threshold){
   if(maxLossPercentDay == 0) return true;
   if(WithinTradingHours(0,1)){
      maxDrawdownSinceOpen = 0;
      equitySinceOpen = AccountInfoDouble(ACCOUNT_EQUITY); 
   }
   double drawdown = equitySinceOpen - AccountInfoDouble(ACCOUNT_EQUITY);
   if(drawdown>maxDrawdownSinceOpen)maxDrawdownSinceOpen=drawdown;
   double maxLossAmount = equitySinceOpen * threshold / 100;
   return maxDrawdownSinceOpen < maxLossAmount;
}
//+------------------------------------------------------------------+
//| close all                                                        |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
    int total = PositionsTotal();
    if (total <= 0) return;

    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        trade.PositionClose(ticket);
    }
   isFirstCandle = false;
   isBuy = false;
   isSell = false;
   cascade=false;
   isHedge = false;
   lotSize = 0.0;
   lotSizeHedgeBuy = 0.0;
   lotSizeHedgeSell = 0.0;
   hedgeAmount = 0;
}
//+------------------------------------------------------------------+
//| close cascade                                                    |
//+------------------------------------------------------------------+
void CloseOlderTrades()
{
    int total = PositionsTotal();
    if (total <= 1) return;
    
    ulong lastTicket = PositionGetTicket(total-1);
    
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket != lastTicket)
        {
            trade.PositionClose(ticket);
        }
    }
}
//+------------------------------------------------------------------+
//| vol                                                              |
//+------------------------------------------------------------------+
bool IsCurrentVolumeHigher()
{
   double myPriceArray[];
   int volumesDef = iVolumes(NULL,PERIOD_CURRENT,VOLUME_TICK);
   ArraySetAsSeries(myPriceArray,true);
   CopyBuffer(volumesDef,0,0,3,myPriceArray);
   float currentVol = (myPriceArray[0]);
   float lastVol = (myPriceArray[1]);
   if(currentVol > lastVol*multiplierVol)return true;
   return false;
}

//+------------------------------------------------------------------+
//| atr                                                              |
//+------------------------------------------------------------------+
double atrValue(int len){
   double priceArray[];
   int atrDef = iATR(NULL,PERIOD_M1,len);
   ArraySetAsSeries(priceArray,true);
   CopyBuffer(atrDef,0,0,3,priceArray);
   double atrValue = NormalizeDouble(priceArray[0],5);
   return atrValue;
}
//+------------------------------------------------------------------+
//| atr spike                                                        |
//+------------------------------------------------------------------+
bool atrSpike(double shortValue, double longValue, double threshold){   
   if(shortValue > longValue * threshold) return true;
   return false;
}
//+------------------------------------------------------------------+
//| Check if new candle has formed                                   |
//+------------------------------------------------------------------+
bool IsNewCandle(ENUM_TIMEFRAMES timeFrame){
   static datetime lastCandleTime;
   datetime currentCandleTime = iTime(NULL,timeFrame,0);
   if(lastCandleTime == currentCandleTime) return false;
   else
     {
      lastCandleTime = currentCandleTime;
      return true;
     }
}
//+------------------------------------------------------------------+
//| check if its within trading hours                                |
//+------------------------------------------------------------------+
bool WithinTradingHours(int startingHour, int endingHour){
   MqlDateTime tm;
   TimeLocal(tm);
   int currentHour = tm.hour;
   return (currentHour >= startingHour && currentHour < endingHour);
}
//+------------------------------------------------------------------+
//| calclate lot size                                                |
//+------------------------------------------------------------------+
double OptimumLotSize(double riskPercent, double stopPoints){
   double oneLotEqual = SymbolInfoDouble(NULL, SYMBOL_TRADE_CONTRACT_SIZE);
   double tickValue = SymbolInfoDouble(NULL, SYMBOL_TRADE_TICK_VALUE);
   double maxLossAccountCurrency = riskPercent/100 * AccountInfoDouble(ACCOUNT_BALANCE);
   double opLot = NormalizeDouble(maxLossAccountCurrency / ((oneLotEqual * tickValue) * MathAbs(stopPoints)), 2);

   if(opLot < 0.01)
     {
      opLot = 0.01;
      Alert("The calculated lot size is less than 0.01");
     }
     return opLot;
}
//+------------------------------------------------------------------+
//| trade direction                                                  |
//+------------------------------------------------------------------+
bool DirectionLong()
{
   return iClose(NULL, PERIOD_M1, 0) > iOpen(NULL, PERIOD_M1, 0);
}
bool DirectionShort()
{
   return iClose(NULL, PERIOD_M1, 0) < iOpen(NULL, PERIOD_M1, 0);
}
//+------------------------------------------------------------------+
//| open a trade                                                     |
//+------------------------------------------------------------------+
void SendTrade(string direction, double lotSize, double entryPrice, double stopPrice, double profitPrice, string comment)
{ 
   Print("");
   string tradeInfo = "Direction: " + direction + ", Lot Size: " + lotSize + ", Entry Price: " + entryPrice + ", Stop Price: " + stopPrice + ", Profit Price: " + profitPrice + ", Comment: " + comment;
   Print(tradeInfo);
   
   if(direction == "buy") trade.Buy(lotSize,NULL,entryPrice,stopPrice,profitPrice,comment);
   if(direction == "sell") trade.Sell(lotSize,NULL,entryPrice,stopPrice,profitPrice,comment);
}
//+------------------------------------------------------------------+
//| draw a vertical line on the chart                                |
//+------------------------------------------------------------------+
void Vline()
{
   ObjectCreate(0, "Vline", OBJ_VLINE, 0, TimeCurrent(), 0);
   ObjectSetInteger(0, "Vline", OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, "Vline", OBJPROP_WIDTH, 1);
}
//+------------------------------------------------------------------+
//| Display parameters on the chart                                  |
//+------------------------------------------------------------------+


#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <..\Experts\newsBT\newsDownloader.mqh>;

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= General settings =========";
input long InpMagicNumber = 9000;    // Magic number
input double InpRisk = 1.0;          // Risk size
input double InpATRMultiplier = 4.0; // ATR Trail SL Multiplier (0 = disabled)
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_M15; // ATR Timeframe

input group "========= Importance =========";
input bool InpImportance_low = false;      // low
input bool InpImportance_moderate = false; // moderate
input bool InpImportance_high = true;      // high

economicNews newsHist[];
datetime previousT;

int OnInit()
{  
   Print(Volume());
   //getBTnews(PeriodSeconds(PERIOD_MN1)*120,newsHist);
   //Print(ArraySize(newsHist));
   trade.SetExpertMagicNumber(InpMagicNumber);
   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Comment("");
}

void OnTick()
{
   //Print("ATR: ",AtrValue());
   
   if (iTime(Symbol(),PERIOD_CURRENT,0) != previousT){
      IsNewsEvent(); 
      Trail();
   }
      
   //if (IsNewBar(PERIOD_M15)) 
}

bool IsNewBar(ENUM_TIMEFRAMES timeFrame)
{
   static datetime previousTime = 0;
   datetime currentTime = iTime(Symbol(), timeFrame, 0);
   if (previousTime != currentTime)
   {
      previousTime = currentTime;
      return true;
   }
   return false;
}

double AtrValue()
{
   double priceArray[];
   int atrDef = iATR(Symbol(), InpTimeFrame, 100);
   ArraySetAsSeries(priceArray, true);
   CopyBuffer(atrDef, 0, 0, 1, priceArray);
   double atrValue = NormalizeDouble(priceArray[0] * InpATRMultiplier, Digits());
   return atrValue;
}

double Volume()
{
   double atrValue = AtrValue();
   if(atrValue==0){
      atrValue=500;
   }

   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRisk / 100;
   double moneyLotStep = (atrValue / tickSize) * tickValue * lotStep;
   //Print(atrValue, " > " , tickSize, " > ", tickValue, " > ", lotStep, " > ", riskMoney, " > ", moneyLotStep);
   double lots = MathRound(riskMoney / moneyLotStep) * lotStep;

   double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

   if (InpATRMultiplier == 0 || moneyLotStep == 0)
      lots = InpRisk;

   if (lots < minVol)
   {
      Print(lots, " > Adjusted to minimum volume > ", minVol);
      lots = minVol;
   }
   else if (lots > maxVol)
   {
      Print(lots, " > Adjusted to minimum volume > ", maxVol);
      lots = maxVol;
   }

   return lots;
}

void IsNewsEvent()
{
   //economicNews newsHist[];
   if(iTime(Symbol(),PERIOD_CURRENT,0) != previousT){
      previousT =iTime(Symbol(),PERIOD_CURRENT,0);
      getBTnews(PeriodSeconds(PERIOD_CURRENT),newsHist);
   }
   
   datetime candleOpen = iTime(Symbol(), PERIOD_M15, 0);
   
   string margin = SymbolInfoString(Symbol(), SYMBOL_CURRENCY_MARGIN);
   string profit = SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT);
   string symbol = margin+" / "+profit;
   //Print(symbol);
   for (int i = 0; i < ArraySize(newsHist); i++)
   {
      
      MqlCalendarEvent event = newsHist[i].event;
      MqlCalendarValue value = newsHist[i].value;
      MqlCalendarCountry country = newsHist[i].country;
        
      string currency = country.currency;
     // Print(currency);
      if (StringFind(symbol,currency) < 0)
         continue;
      
     //Print(value.time," > ", candleOpen, value.time == candleOpen); 
      if ((string) value.time != (string) candleOpen) 
         continue;
         
      if (event.importance == CALENDAR_IMPORTANCE_NONE)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_LOW && !InpImportance_low)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_MODERATE && !InpImportance_moderate)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_HIGH && !InpImportance_high)
         continue;
      
         
       // Print("!");
      
         string msg = (" currency: " + currency + " name: " + event.name + " impact: " + (value.impact_type == CALENDAR_IMPACT_POSITIVE ? "positive" : "negative") + " eventtime: " + (string)value.time + " triggertime: " + (string)TimeCurrent());
         string comment = (currency + (value.impact_type == CALENDAR_IMPACT_POSITIVE ? "+ " : "- ") + event.name);

         Print(msg);
         double volume = Volume();
         double slLong = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_BID) - AtrValue(), Digits());
         double slShort = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_ASK) + AtrValue(), Digits());
         
         if (currency == margin)
         {

            if (value.impact_type == CALENDAR_IMPACT_POSITIVE)
               trade.Buy(volume, Symbol(), 0, slLong, 0, comment);
            else if (value.impact_type == CALENDAR_IMPACT_NEGATIVE)
               trade.Sell(volume, Symbol(), 0, slShort, 0, comment);
         }
         else if (currency == profit)
         {

            if (value.impact_type == CALENDAR_IMPACT_POSITIVE)
               trade.Sell(volume, Symbol(), 0, slShort, 0, comment);
            else if (value.impact_type == CALENDAR_IMPACT_NEGATIVE)
               trade.Buy(volume, Symbol(), 0, slLong, 0, comment);
         }
         else
           {
            Print("Didnt take trade but passed checks> C:", currency," S: ", symbol, event.name);
           }
         
         if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
         {
            Print("Failed to open position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
            Print("vol: ", volume," sym: ", Symbol(), " en: ", 0, " sl: ", slLong, " tp: ", 0, " c: ", comment);
            return;
         }

         Comment(comment);
      
   }
}

// trail sl based on atr
void Trail()
{
   if (InpATRMultiplier == 0)
      return;

   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--)
   {
      if (total != PositionsTotal())
      {
         total = PositionsTotal();
         i = total;
         continue;
      }
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0)
      {
         Print("Failed to get position ticket");
         return;
      }
      if (!PositionSelectByTicket(ticket))
      {
         Print("Failed to select position by ticket");
         return;
      }
      long magicNumber;
      if (!PositionGetInteger(POSITION_MAGIC, magicNumber))
      {
         Print("Failed to get position magic number");
         return;
      }
      if (InpMagicNumber != magicNumber)
         continue;

      if (PositionGetString(POSITION_SYMBOL) != Symbol())
         continue;

      // get the stop loss
      double stopLoss;
      if (!PositionGetDouble(POSITION_SL, stopLoss))
      {
         Print("Failed to get position stop loss");
         return;
      }

      // get the trade type
      long positionType;
      if (!PositionGetInteger(POSITION_TYPE, positionType))
      {
         Print("Failed to get position type");
         return;
      }
      
      // get expected stop loss, based on atr
      double expectedStopLoss = 0;
      double high = iHigh(Symbol(),PERIOD_CURRENT,0);
      double low = iLow(Symbol(),PERIOD_CURRENT,0);
      double bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);
      double ask = SymbolInfoDouble(Symbol(),SYMBOL_BID);
      
      if (positionType == (long)POSITION_TYPE_BUY)
      {
         expectedStopLoss = NormalizeDouble(bid - AtrValue(), Digits());
      }
      else if (positionType == (long)POSITION_TYPE_SELL)
      {
         expectedStopLoss = NormalizeDouble(ask + AtrValue(), Digits());
      }
      else
        {
         Print("Failed to get position type for expectedStopLoss");
        }

      if (expectedStopLoss == 0){
         Print("Expected sl is 0");
         continue;
      }
      
      if (stopLoss == 0 || (positionType == (long)POSITION_TYPE_BUY && expectedStopLoss > stopLoss) || (positionType == (long)POSITION_TYPE_SELL && expectedStopLoss < stopLoss))
      {
         trade.PositionModify(ticket, expectedStopLoss, 0);
         if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
         {
            Print("Failed to modify position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
            return;
         }
      }
   }

   return;
}

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= General settings =========";
input long InpMagicNumber = 888;                // Magic
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_H1; // timeFrame

input group "========= Risk settings =========";
enum RISK_MODE_ENUM
{
   RISK_MODE_1, // Safe
   RISK_MODE_2, // Low
   RISK_MODE_3, // Moderate
   RISK_MODE_4, // High
   RISK_MODE_5, // Extreme
};
input RISK_MODE_ENUM InpRiskMode = RISK_MODE_3; // Risk
double InpRisk;

enum TRAILING_STOP_MODE_ENUM
{
   TRAILING_STOP_MODE_0,   // Off
   TRAILING_STOP_MODE_25,  // 25%
   TRAILING_STOP_MODE_50,  // 50%
   TRAILING_STOP_MODE_75,  // 75%
   TRAILING_STOP_MODE_100, // 100%
};
input TRAILING_STOP_MODE_ENUM InpTrailingStopMode = TRAILING_STOP_MODE_100; // Trail
double InpTrailingStop = 0;

input group "========= Importance =========";
input bool InpImportance_low = false;     // low
input bool InpImportance_moderate = true; // moderate
input bool InpImportance_high = true;     // high

MqlCalendarValue hist[];
MqlCalendarValue news[];

int OnInit()
{
   if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_1)
      InpRisk = 0.1;
   else if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_2)
      InpRisk = 0.5;
   else if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_3)
      InpRisk = 1;
   else if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_4)
      InpRisk = 2.5;
   else if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_5)
      InpRisk = 5;

   if (TRAILING_STOP_MODE_ENUM(InpTrailingStopMode) == TRAILING_STOP_MODE_0)
      InpTrailingStop = 0;
   else if (TRAILING_STOP_MODE_ENUM(InpTrailingStopMode) == TRAILING_STOP_MODE_25)
      InpTrailingStop = 25;
   else if (TRAILING_STOP_MODE_ENUM(InpTrailingStopMode) == TRAILING_STOP_MODE_50)
      InpTrailingStop = 50;
   else if (TRAILING_STOP_MODE_ENUM(InpTrailingStopMode) == TRAILING_STOP_MODE_75)
      InpTrailingStop = 75;
   else if (TRAILING_STOP_MODE_ENUM(InpTrailingStopMode) == TRAILING_STOP_MODE_100)
      InpTrailingStop = 100;
   InpTrailingStop = InpTrailingStop / 100;

   Print(AtrValue("AUDUSD"), " ", AtrValue("EURUSD"), " ", AtrValue("GBPUSD"), " ", AtrValue("USDCAD"), " ", AtrValue("USDCHF"), " ", AtrValue("USDJPY"), " ", AtrValue("XAUUSD"));
   Print(Volume("AUDUSD"), " ", Volume("EURUSD"), " ", Volume("GBPUSD"), " ", Volume("USDCAD"), " ", Volume("USDCHF"), " ", Volume("USDJPY"), " ", Volume("XAUUSD"));

   trade.SetExpertMagicNumber(InpMagicNumber);
   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Comment("");
}

void OnTick()
{
   if (IsNewBar(PERIOD_D1))
   {
      GetCalendarValue(hist);
      Print(AtrValue("AUDUSD"), " ", AtrValue("EURUSD"), " ", AtrValue("GBPUSD"), " ", AtrValue("USDCAD"), " ", AtrValue("USDCHF"), " ", AtrValue("USDJPY"), " ", AtrValue("XAUUSD"));
      Print(Volume("AUDUSD"), " ", Volume("EURUSD"), " ", Volume("GBPUSD"), " ", Volume("USDCAD"), " ", Volume("USDCHF"), " ", Volume("USDJPY"), " ", Volume("XAUUSD"));
   }
   IsNewsEvent();
   CheckTrades();
}

bool IsNewBar(ENUM_TIMEFRAMES timeFrame)
{
   static int barsTotal;
   int bars = iBars(Symbol(), timeFrame);
   if (barsTotal != bars)
   {
      barsTotal = bars;
      return true;
   }
   return false;
}

double AtrValue(string symbol)
{
   int atrHandle;
   atrHandle = iATR(symbol, InpTimeFrame, 999);
   double priceArray[];
   ArraySetAsSeries(priceArray, true);
   CopyBuffer(atrHandle, 0, 0, 1, priceArray);
   double atrValue = priceArray[0];
   return atrValue;
}

double Volume(string symbol, int volDivider = 1)
{
   double atr = AtrValue(symbol);

   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRisk / volDivider / 100;
   double moneyLotStep = (atr / tickSize) * tickValue * lotStep;

   double lots = MathRound(riskMoney / moneyLotStep) * lotStep;

   double minVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   if (lots < minVol)
   {
      Print(lots, " > Adjusted to minimum volume > ", minVol, " Atr: ", atr);
      lots = minVol;
   }
   else if (lots > maxVol)
   {
      Print(lots, " > Adjusted to maximum volume > ", maxVol, " Atr: ", atr);
      lots = maxVol;
   }

   return lots;
}

void GetCalendarValue(MqlCalendarValue &values[])
{
   datetime startTime = iTime(Symbol(), PERIOD_W1, 0);
   datetime endTime = startTime + PeriodSeconds(PERIOD_W1);
   ArrayFree(values);
   CalendarValueHistory(values, startTime, endTime, NULL, NULL);
}

void IsNewsEvent()
{
   GetCalendarValue(news);
   int amount = ArraySize(news);
   if (amount != ArraySize(hist))
      return;

   for (int i = amount - 1; i >= 0; i--)
   {

      MqlCalendarEvent event;
      CalendarEventById(news[i].event_id, event);

      MqlCalendarEvent histEvent;
      CalendarEventById(hist[i].event_id, event);
      if (event.id != histEvent.id)
         continue;

      MqlCalendarCountry country;
      CalendarCountryById(event.country_id, country);
      string currency = country.currency;

      if (event.importance == CALENDAR_IMPORTANCE_NONE)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_LOW && !InpImportance_low)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_MODERATE && !InpImportance_moderate)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_HIGH && !InpImportance_high)
         continue;

      string symbol;
      string margin;
      string profit;
      if (currency == "AUD")
      {
         symbol = "AUDUSD";
         margin = "AUD";
         profit = "USD";
      }
      else if (currency == "EUR")
      {
         symbol = "EURUSD";
         margin = "EUR";
         profit = "USD";
      }
      else if (currency == "GBP")
      {
         symbol = "GBPUSD";
         margin = "GBP";
         profit = "USD";
      }
      else if (currency == "CAD")
      {
         symbol = "USDCAD";
         margin = "USD";
         profit = "CAD";
      }
      else if (currency == "CHF")
      {
         symbol = "USDCHF";
         margin = "USD";
         profit = "CHF";
      }
      else if (currency == "JPY")
      {
         symbol = "USDJPY";
         margin = "USD";
         profit = "JPY";
      }
      else if (currency == "USD")
      {
         symbol = "XAUUSD";
         margin = "XAU";
         profit = "USD";
      }
      else
         continue;

      ENUM_CALENDAR_EVENT_IMPACT newsImpact = news[i].impact_type;
      ENUM_CALENDAR_EVENT_IMPACT histImpact = hist[i].impact_type;
      if (!((newsImpact == CALENDAR_IMPACT_POSITIVE || newsImpact == CALENDAR_IMPACT_NEGATIVE) && newsImpact != histImpact))
         continue;

      string msg = currency + (newsImpact == CALENDAR_IMPACT_POSITIVE ? "+ " : "- ") + event.name + " " + (string)event.importance;
      bool isBuy = (currency == margin && newsImpact == CALENDAR_IMPACT_POSITIVE) ||
                   (currency != margin && newsImpact == CALENDAR_IMPACT_NEGATIVE);

      if (news[i].actual_value == news[i].forecast_value)
         continue;

      if (event.importance == CALENDAR_IMPORTANCE_MODERATE)
         executeTrade(symbol, isBuy, msg, 2);
      else
         executeTrade(symbol, isBuy, msg);

      hist[i] = news[i];
      Print(msg);
   }
}

void executeTrade(string symbol, bool isBuy, string msg, int volDivider = 1)
{
   double atr = AtrValue(symbol);

   if (isBuy)
   {
      double stopLoss = SymbolInfoDouble(symbol, SYMBOL_ASK) - atr;
      trade.Buy(Volume(symbol, volDivider), symbol, 0, stopLoss, 0, msg);
   }
   else
   {
      double stopLoss = SymbolInfoDouble(symbol, SYMBOL_BID) + atr;
      trade.Sell(Volume(symbol, volDivider), symbol, 0, stopLoss, 0, msg);
   }
   if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
   {
      Print("Failed to open position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
      return;
   }
}

void CheckTrades()
{
   CheckClose();
   CheckTrail();
}

void CheckClose()
{
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
      string symbol;
      if (!PositionGetString(POSITION_SYMBOL, symbol))
      {
         Print("Failed to get position symbol");
         return;
      }
      datetime openTime;
      if (!PositionGetInteger(POSITION_TIME, openTime))
      {
         Print("Failed to get position open time");
         return;
      }

      // check for close
      if (TimeCurrent() > openTime + PeriodSeconds(InpTimeFrame))
      {
         trade.PositionClose(ticket);
         if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
         {
            Print("Failed to close position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
            return;
         }
      }
   }
}

void CheckTrail()
{
   if (InpTrailingStop == 0)
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
      string symbol;
      if (!PositionGetString(POSITION_SYMBOL, symbol))
      {
         Print("Failed to get position symbol");
         return;
      }
      long positionType;
      if (!PositionGetInteger(POSITION_TYPE, positionType))
      {
         Print("Failed to get position type");
         return;
      }
      double entryPrice;
      if (!PositionGetDouble(POSITION_PRICE_OPEN, entryPrice))
      {
         Print("Failed to get position open price");
         return;
      }
      double stopLoss;
      if (!PositionGetDouble(POSITION_SL, stopLoss))
      {
         Print("Failed to get position stop loss");
         return;
      }

      double currentPrice = (SymbolInfoDouble(symbol, SYMBOL_ASK) + SymbolInfoDouble(symbol, SYMBOL_BID)) / 2;
      double atr = AtrValue(symbol);
      double trail = atr * InpTrailingStop;
      int multiplier = ((int)MathFloor(MathAbs(currentPrice - entryPrice) / trail));
      double newStopLoss = 0;

      if (multiplier < 1)
         continue;

      if (positionType == POSITION_TYPE_BUY && currentPrice > entryPrice)
      {
         newStopLoss = entryPrice + trail * (multiplier - 1);
      }
      else if (positionType == POSITION_TYPE_SELL && currentPrice < entryPrice)
      {
         newStopLoss = entryPrice - trail * (multiplier - 1);
      }

      if (newStopLoss == stopLoss || newStopLoss == 0)
         continue;

      trade.PositionModify(ticket, newStopLoss, 0);
      if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
      {
         Print("Failed to modify position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
         return;
      }
   }
}

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= settings 1 =========";
input long InpMagicNumber = 9000; // Magic number
input double InpRisk = 0.01;      // Risk size
input int InpTradeDuration = 60;  // trade duration in minutes (0 = disabled)

input group "========= settings 2 =========";
input int InpStopLoss = 0;   // Stop Loss in points (0 = disabled)
input int InpTakeProfit = 0; // Take Profit in points (0 = disabled)

input group "========= settings 3 =========";
input bool InpImportance_low = false;      // low
input bool InpImportance_moderate = false; // moderate
input bool InpImportance_high = true;      // high

input group "========= settings 4 =========";
input bool InpMonday = true;    // Range on Monday
input bool InpTuesday = true;   // Range on Tuesday
input bool InpWednesday = true; // Range on Wednesday
input bool InpThursday = true;  // Range on Thursday
input bool InpFriday = true;    // Range on Friday

MqlCalendarValue calendarValues[];
double lotSize = InpRisk;

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   Print(SymbolInfoString(Symbol(), SYMBOL_CURRENCY_MARGIN), " / ", SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT));

   static double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   static double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   if (InpRisk < minVol)
   {
      Print(InpRisk, " > Adjusted to minimum volume > ", minVol);
      lotSize = minVol;
   }
   else if (InpRisk > maxVol)
   {
      lotSize = maxVol;
      Print(InpRisk, " > Adjusted to minimum volume > ", maxVol);
   }
   else
   {
      Print("Risk: ", lotSize);
   }

   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
   if (IsNewBar(PERIOD_D1))
   {
      datetime startTime = iTime(Symbol(), PERIOD_MN1, 1);
      datetime endTime = iTime(Symbol(), PERIOD_MN1, 0) + PeriodSeconds(PERIOD_MN1);

      CalendarValueHistory(calendarValues, startTime, endTime, NULL, NULL);
      
      for (int i = 0; i < ArraySize(calendarValues); i++)
      {
         MqlCalendarEvent event;
         CalendarEventById(calendarValues[i].event_id, event);
         MqlCalendarCountry country;
         CalendarCountryById(event.country_id, country);
         string print = (" currency: " + country.currency + " name: " + event.name + " impact: " + (calendarValues[i].impact_type == CALENDAR_IMPACT_POSITIVE ? "positive" : "negative") + " eventtime: " + (string)calendarValues[i].time + " triggertime: " + (string)TimeCurrent());

         Print(print);
      }
   }

   isNewsEvent();
   BreakEven();
   ClosePositions();
}

void isNewsEvent()
{
   MqlCalendarValue values[];

   datetime startTime = iTime(Symbol(), PERIOD_D1, 0);
   datetime endTime = startTime + PeriodSeconds(PERIOD_D1);

   CalendarValueHistory(values, startTime, endTime, NULL, NULL);

   for (int i = 0; i < ArraySize(values); i++)
   {

      MqlCalendarEvent event;
      CalendarEventById(values[i].event_id, event);

      MqlCalendarCountry country;
      CalendarCountryById(event.country_id, country);

      if (country.currency != SymbolInfoString(Symbol(), SYMBOL_CURRENCY_MARGIN) || country.currency != SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT))
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_NONE)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_LOW && !InpImportance_low)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_MODERATE && !InpImportance_moderate)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_HIGH && !InpImportance_high)
         continue;

      if (values[i].impact_type != CALENDAR_IMPACT_NA && calendarValues[i].impact_type == CALENDAR_IMPACT_NA)
      {
         string msg = (" currency: " + country.currency + " name: " + event.name + " impact: " + (values[i].impact_type == CALENDAR_IMPACT_POSITIVE ? "positive" : "negative") + " eventtime: " + (string)values[i].time + " triggertime: " + (string)TimeCurrent());

         if (country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_MARGIN))
         {

            if (values[i].impact_type == CALENDAR_IMPACT_POSITIVE)
               trade.Buy(lotSize, NULL, 0, 0, 0, msg);
            else if (values[i].impact_type == CALENDAR_IMPACT_NEGATIVE)
               trade.Sell(lotSize, NULL, 0, 0, 0, msg);
         }
         else
         {

            if (values[i].impact_type == CALENDAR_IMPACT_POSITIVE)
               trade.Sell(lotSize, NULL, 0, 0, 0, msg);
            else if (values[i].impact_type == CALENDAR_IMPACT_NEGATIVE)
               trade.Buy(lotSize, NULL, 0, 0, 0, msg);
         }

         calendarValues[i] = values[i];

         Print(msg);
         Comment(msg);
      }
   }
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

// close trades after x minutes
void ClosePositions()
{
   if (InpTradeDuration == 0)
      return;

   // calculate maximum open time
   datetime maxOpenTime = TimeCurrent() - InpTradeDuration * PeriodSeconds(PERIOD_M1);

   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--)
   {
      if (total != PositionsTotal())
      {
         total = PositionsTotal();
         i = total;
         continue;
      }
      ulong ticket = PositionGetTicket(i); // select position
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

      datetime openTime;
      if (!PositionGetInteger(POSITION_TIME, openTime))
      {
         Print("Failed to get position open time");
         return;
      }
      if (openTime > maxOpenTime)
         continue;

      trade.PositionClose(ticket);
      if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
      {
         Print("Failed to close position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
         return;
      }
   }

   return;
}

// break even if trade is in profit after InpTradeDuration/2 minutes
void BreakEven()
{
   if (InpTradeDuration == 0)
      return;

   // calculate maximum open time
   datetime maxOpenTime = TimeCurrent() - (int)MathRound(InpTradeDuration / 2) * PeriodSeconds(PERIOD_M1);

   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--)
   {
      if (total != PositionsTotal())
      {
         total = PositionsTotal();
         i = total;
         continue;
      }
      ulong ticket = PositionGetTicket(i); // select position
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

      datetime openTime;
      if (!PositionGetInteger(POSITION_TIME, openTime))
      {
         Print("Failed to get position open time");
         return;
      }
      if (openTime > maxOpenTime)
         continue;
      double entryPrice;
      if (!PositionGetDouble(POSITION_PRICE_OPEN, entryPrice))
      {
         Print("Failed to get position entry price");
         return;
      }
      double takeProfit;
      if (!PositionGetDouble(POSITION_TP, takeProfit))
      {
         Print("Failed to get position take profit");
         return;
      }
      long type;
      if (!PositionGetInteger(POSITION_TYPE, type))
      {
         Print("Failed to get position type");
         continue;
      }
      if ((type == POSITION_TYPE_BUY && entryPrice + 10 * SymbolInfoDouble(Symbol(), SYMBOL_POINT) > takeProfit) || (type == POSITION_TYPE_SELL && entryPrice - 10 * SymbolInfoDouble(Symbol(), SYMBOL_POINT) < takeProfit))
         trade.PositionModify(ticket, entryPrice, takeProfit);
      if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
      {
         Print("Failed to close position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
         return;
      }
   }

   return;
}
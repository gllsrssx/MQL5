#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= General settings =========";
input long InpMagicNumber = 9000;    // Magic number
input double InpRisk = 5.0;          // Risk size
input double InpATRMultiplier = 2.0; // ATR Trail SL Multiplier (0 = disabled)
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_CURRENT;

input group "========= Importance =========";
input bool InpImportance_low = false;      // low
input bool InpImportance_moderate = false; // moderate
input bool InpImportance_high = true;      // high

MqlCalendarValue calendarValues[];

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);

   Comment(SymbolInfoString(Symbol(), SYMBOL_CURRENCY_MARGIN), " / ", SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT));

   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
   if (IsNewBar(PERIOD_D1))
   {
      datetime startTime = iTime(Symbol(), PERIOD_D1, 0);
      datetime endTime = startTime + PeriodSeconds(PERIOD_D1);

      CalendarValueHistory(calendarValues, startTime, endTime, NULL, NULL);
   }

   IsNewsEvent();

   if (IsNewBar(InpTimeFrame))
      Trail();
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
   int atrDef = iATR(Symbol(), InpTimeFrame, 999);
   ArraySetAsSeries(priceArray, true);
   CopyBuffer(atrDef, 0, 0, 1, priceArray);
   double atrValue = NormalizeDouble(priceArray[0], Digits());
   return atrValue * InpATRMultiplier;
}

double Volume()
{
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRisk / 100;
   double moneyLotStep = (AtrValue() / tickSize) * tickValue * lotStep;

   double lots = MathRound(riskMoney / moneyLotStep) * lotStep;

   double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

   if (InpATRMultiplier == 0)
      lots = InpRisk;

   if (lots < minVol)
   {
      Print(lots, " > Adjusted to minimum volume > ", minVol);
      lots = minVol;
   }
   else if (lots > maxVol)
   {
      lots = maxVol;
      Print(lots, " > Adjusted to minimum volume > ", maxVol);
   }

   return lots;
}

void IsNewsEvent()
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

      string currency = country.currency;
      string margin = SymbolInfoString(Symbol(), SYMBOL_CURRENCY_MARGIN);
      string profit = SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT);

      if (currency != margin && currency != profit)
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
         string msg = (" currency: " + currency + " name: " + event.name + " impact: " + (values[i].impact_type == CALENDAR_IMPACT_POSITIVE ? "positive" : "negative") + " eventtime: " + (string)values[i].time + " triggertime: " + (string)TimeCurrent());
         string comment = (currency + (values[i].impact_type == CALENDAR_IMPACT_POSITIVE ? "+ " : "- ") + event.name);

         if (currency == margin)
         {

            if (values[i].impact_type == CALENDAR_IMPACT_POSITIVE)
               trade.Buy(Volume(), NULL, 0, 0, 0, comment);
            else if (values[i].impact_type == CALENDAR_IMPACT_NEGATIVE)
               trade.Sell(Volume(), NULL, 0, 0, 0, comment);
         }
         else
         {

            if (values[i].impact_type == CALENDAR_IMPACT_POSITIVE)
               trade.Sell(Volume(), NULL, 0, 0, 0, comment);
            else if (values[i].impact_type == CALENDAR_IMPACT_NEGATIVE)
               trade.Buy(Volume(), NULL, 0, 0, 0, comment);
         }
         if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
         {
            Print("Failed to open position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
            return;
         }
         calendarValues[i] = values[i];

         Print(msg);
         Comment(comment);
      }
   }
}

// trail sl based on atr
void Trail()
{
   if (InpATRMultiplier)
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

      if (positionType == (long)POSITION_TYPE_BUY)
      {
         expectedStopLoss = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_BID) - AtrValue(), Digits());
      }
      else if (positionType == (long)POSITION_TYPE_SELL)
      {
         expectedStopLoss = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_ASK) + AtrValue(), Digits());
      }

      if (expectedStopLoss == 0)
         continue;

      if (expectedStopLoss != stopLoss)
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

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= Risk settings =========";
input double InpRisk = 0.01; // Risk size
input int InpStopLoss = 0;   // Stop Loss in points (0 = disabled)
input int InpTakeProfit = 0; // Take Profit in points (0 = disabled)
input group "========= Importance settings =========";
input bool InpImportance_low = false;      // low
input bool InpImportance_moderate = false; // moderate
input bool InpImportance_high = true;      // high

MqlCalendarValue calendarValues[];

int OnInit()
{
   Print(SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE), " / ", SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT));
   
   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
   isNewsEvent();
   
   if (IsNewBar(PERIOD_D1))
   {
      datetime startTime = iTime(Symbol(), PERIOD_D1, 0);
      datetime endTime = startTime + PeriodSeconds(PERIOD_D1);

      CalendarValueHistory(calendarValues, startTime, endTime, NULL, NULL);
   }
}

void isNewsEvent()
{
   for (int i = 0; i < ArraySize(calendarValues); i++)
   {
      MqlCalendarValue values[];
      
      datetime startTime = iTime(Symbol(), PERIOD_D1, 0);
      datetime endTime = startTime + PeriodSeconds(PERIOD_D1);

      CalendarValueHistory(values, startTime, endTime, NULL, NULL);
      
      MqlCalendarEvent event;
      CalendarEventById(values[i].event_id, event);

      MqlCalendarCountry country;
      CalendarCountryById(event.country_id, country);

      if (StringFind(Symbol(), country.currency) < 0) continue;
      if (event.importance == CALENDAR_IMPORTANCE_NONE) continue;
      if (event.importance == CALENDAR_IMPORTANCE_LOW && !InpImportance_low) continue;
      if (event.importance == CALENDAR_IMPORTANCE_MODERATE && !InpImportance_moderate) continue;
      if (event.importance == CALENDAR_IMPORTANCE_HIGH && !InpImportance_high) continue;

      if (values[i].impact_type != CALENDAR_IMPACT_NA && calendarValues[i].impact_type == CALENDAR_IMPACT_NA){
         
         calendarValues[i] = values[i];
         
         if(country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE)){
         
            if(values[i].impact_type == CALENDAR_IMPACT_POSITIVE) trade.Buy(InpRisk, Symbol(), 0, InpStopLoss>0? SymbolInfoDouble(Symbol(), SYMBOL_BID)-InpStopLoss: 0, InpTakeProfit>0? SymbolInfoDouble(Symbol(), SYMBOL_BID)+InpTakeProfit: 0);
            else if(values[i].impact_type == CALENDAR_IMPACT_NEGATIVE) trade.Sell(InpRisk, Symbol(), 0, InpStopLoss>0? SymbolInfoDouble(Symbol(), SYMBOL_BID)+InpStopLoss: 0, InpTakeProfit>0? SymbolInfoDouble(Symbol(), SYMBOL_BID)-InpTakeProfit: 0);
         } else {
         
            if(values[i].impact_type == CALENDAR_IMPACT_POSITIVE) trade.Sell(InpRisk, Symbol(), 0, InpStopLoss>0? SymbolInfoDouble(Symbol(), SYMBOL_BID)+InpStopLoss: 0, InpTakeProfit>0? SymbolInfoDouble(Symbol(), SYMBOL_BID)-InpTakeProfit: 0);
            else if(values[i].impact_type == CALENDAR_IMPACT_NEGATIVE) trade.Buy(InpRisk, Symbol(), 0, InpStopLoss>0? SymbolInfoDouble(Symbol(), SYMBOL_BID)-InpStopLoss: 0, InpTakeProfit>0? SymbolInfoDouble(Symbol(), SYMBOL_BID)+InpTakeProfit: 0);
         }  
         Print(" name: ", event.name, " impact: ", values[i].impact_type == CALENDAR_IMPACT_POSITIVE? "positive":"negative", " eventtime: ", values[i].time, " triggertime: ", TimeCurrent());
         Comment(" name: ", event.name, " impact: ", values[i].impact_type == CALENDAR_IMPACT_POSITIVE? "positive":"negative", " eventtime: ", values[i].time, " triggertime: ", TimeCurrent());
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

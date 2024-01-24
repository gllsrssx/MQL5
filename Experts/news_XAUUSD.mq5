#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

input group "========= Risk settings =========";
input double InpLots = 0.01;                    // Risk size
input int InpStopLoss = 0;                      // Stop Loss in points (0 = disabled)
input int InpTakeProfit = 0;                    // Take Profit in points (0 = disabled)
input group "========= Importance settings =========";
input bool InpImportance_low = false;           // low
input bool InpImportance_moderate = false;      // moderate
input bool InpImportance_high = true;           // high

int OnInit()
{

   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{

}

void OnTick()
{
   if(IsNewBar(PERIOD_M1)){
      Print("------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
      Print(TimeCurrent());
      isNewsEvent();
   }
}

void isNewsEvent()
{
  MqlCalendarValue calendarValues[];

  datetime startTime = iTime(Symbol(), PERIOD_D1, 0);
  datetime endTime = startTime + PeriodSeconds(PERIOD_D1);

  CalendarValueHistory(calendarValues, startTime, endTime, NULL, NULL);

  for(int i = 0; i < ArraySize(calendarValues); i++)
  {
    MqlCalendarEvent event;
    CalendarEventById(calendarValues[i].event_id, event);

    MqlCalendarCountry country;
    CalendarCountryById(event.country_id, country);

    if(StringFind(Symbol(), country.currency) < 0) continue;
    if(event.importance == CALENDAR_IMPORTANCE_NONE) continue;
    if(event.importance == CALENDAR_IMPORTANCE_LOW) continue;
    if(event.importance == CALENDAR_IMPORTANCE_MODERATE) continue;

    if(TimeCurrent() >= calendarValues[i].time - PeriodSeconds(PERIOD_H2) && TimeCurrent() <= calendarValues[i].time + 60 * PeriodSeconds(PERIOD_H2)){
      string impact = calendarValues[i].impact_type == CALENDAR_IMPACT_NEGATIVE ? "negative impact" : calendarValues[i].impact_type == CALENDAR_IMPACT_POSITIVE ? "positive impact" : "no impact";
      Print(" ", calendarValues[i].time, " > ", country.currency ," > ", event.name, " ", impact);
    }
  }
}

bool IsNewBar(ENUM_TIMEFRAMES timeFrame){
   static datetime previousTime = 0;
   datetime currentTime = iTime(Symbol(), timeFrame, 0);
   if(previousTime != currentTime){
      previousTime = currentTime;    
      return true;  
   }
   return false;
}
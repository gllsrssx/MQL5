#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= General settings =========";
input long InpMagicNumber = 888;                // Magic
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_H4; // timeFrame

input group "========= Risk settings =========";
enum RISK_MODE_ENUM
{
   RISK_MODE_INFO, // %/2 for not high impact news
   RISK_MODE_1,    // 0.1%
   RISK_MODE_2,    // 0.2%
   RISK_MODE_3,    // 0.5%
   RISK_MODE_4,    // 1%
   RISK_MODE_5,    // 2%
   RISK_MODE_6,    // 5%
   RISK_MODE_7,    // 10%
   RISK_MODE_8,    // 20%
};
input RISK_MODE_ENUM InpRiskMode = RISK_MODE_3; // Medium Risk
double InpRisk;

enum TRAILING_STOP_MODE_ENUM
{
   TRAILING_STOP_MODE_0,   // Off
   TRAILING_STOP_MODE_25,  // 25%
   TRAILING_STOP_MODE_50,  // 50%
   TRAILING_STOP_MODE_75,  // 75%
   TRAILING_STOP_MODE_100, // 100%
};
input TRAILING_STOP_MODE_ENUM InpTrailingStopMode = TRAILING_STOP_MODE_25; // Trail
double InpTrailingStop = 0;

// input group "========= Importance =========";
bool InpImportance_low = false;     // low
bool InpImportance_moderate = true; // moderate
bool InpImportance_high = true;     // high

MqlCalendarValue hist[];
MqlCalendarValue news[];

int handleAtr;
double bufferAtr[];

int OnInit()
{
   if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_1)
      InpRisk = 0.1;
   else if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_2)
      InpRisk = 0.2;
   else if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_3)
      InpRisk = 0.5;
   else if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_4)
      InpRisk = 1;
   else if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_5)
      InpRisk = 2;
   else if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_6)
      InpRisk = 5;
   else if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_7)
      InpRisk = 10;
   else if (RISK_MODE_ENUM(InpRiskMode) == RISK_MODE_8)
      InpRisk = 20;
   InpRisk = InpRisk / 100;

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

   GetCalendarValue(hist);
   Plot();

   trade.SetExpertMagicNumber(InpMagicNumber);

   if (MQLInfoInteger(MQL_TESTER))
   {
      downloadNews();
      getBTnewsAll(nieuwsTester);
      Print("nieuwsTester: ", ArraySize(nieuwsTester));
   }

   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Comment("");
}

void OnTick()
{
   if (MQLInfoInteger(MQL_TESTER))
   {
      OnTickTester();
      return;
   }

   IsNewsEvent();
   CheckTrades();
   if (IsNewBar(PERIOD_D1))
   {
      GetCalendarValue(hist);
      Plot();
   }
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
   handleAtr = iATR(symbol, InpTimeFrame, 120);
   ArraySetAsSeries(bufferAtr, true);
   CopyBuffer(handleAtr, 0, 0, 3, bufferAtr);
   double atrValue = Normalize(symbol, bufferAtr[0]);
   return atrValue;
}

double capital = AccountInfoDouble(ACCOUNT_BALANCE);
double Volume(string symbol, int volDivider = 1)
{
   if (!MQLInfoInteger(MQL_TESTER))
      capital = AccountInfoDouble(ACCOUNT_BALANCE);
   double atr = AtrValue(symbol);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRisk / volDivider;
   double moneyLotStep = atr / tickSize * tickValue * lotStep;
   double lots = MathRound(riskMoney / moneyLotStep) * lotStep;
   double minVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   if (!(atr > 0))
   {
      Print(atr, " Failed to get ATR value, sending minVol: ", minVol);
      return minVol;
   }
   else if (lots < minVol)
   {
      Print(lots, " > Adjusted to minimum volume > ", minVol, " Atr: ", atr);
      return minVol;
   }
   else if (lots > maxVol)
   {
      Print(lots, " > Adjusted to maximum volume > ", maxVol, " Atr: ", atr);
      return maxVol;
   }

   return NormalizeDouble(lots, 2);
}

double Normalize(string symbol, double price)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double result = NormalizeDouble(price, digits);
   return result;
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

      if (news[i].actual_value == news[i].forecast_value || news[i].actual_value == news[i].prev_value)
      {
         hist[i] = news[i];
         Print("No change in actual value >" + msg);
         continue;
      }

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
      double stopLoss = Normalize(symbol, SymbolInfoDouble(symbol, SYMBOL_ASK) - atr);
      trade.Buy(Volume(symbol, volDivider), symbol, 0, stopLoss, 0, msg);
   }
   else
   {
      double stopLoss = Normalize(symbol, SymbolInfoDouble(symbol, SYMBOL_BID) + atr);
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

      double currentPrice = Normalize(symbol, (SymbolInfoDouble(symbol, SYMBOL_ASK) + SymbolInfoDouble(symbol, SYMBOL_BID)) / 2);
      double atr = AtrValue(symbol);
      double trail = Normalize(symbol, atr * InpTrailingStop);
      int multiplier = ((int)MathFloor(MathAbs(currentPrice - entryPrice) / trail));
      double newStopLoss = 0;

      if (multiplier < 1)
         continue;

      if (positionType == POSITION_TYPE_BUY && currentPrice > entryPrice)
      {
         newStopLoss = Normalize(symbol, entryPrice + trail * (multiplier - 1));
      }
      else if (positionType == POSITION_TYPE_SELL && currentPrice < entryPrice)
      {
         newStopLoss = Normalize(symbol, entryPrice - trail * (multiplier - 1));
      }

      if (newStopLoss == stopLoss || newStopLoss == 0 || (positionType == POSITION_TYPE_BUY && newStopLoss < stopLoss) || (positionType == POSITION_TYPE_SELL && newStopLoss > stopLoss))
         continue;

      trade.PositionModify(ticket, newStopLoss, 0);
      if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
      {
         Print("Failed to modify position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
         return;
      }
   }
}

double realBalance;
double maxDrawdown;
string DrawDown()
{
   string result = "";
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if (balance > realBalance)
      realBalance = balance;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = 100 - equity / realBalance * 100;
   if (drawdown > maxDrawdown)
      maxDrawdown = drawdown;
   maxDrawdown = NormalizeDouble(maxDrawdown, 2);
   if (maxDrawdown == 0)
      return result;
   return "Drawdown: " + (string)maxDrawdown + "%";
   return result;
}

double accBal = AccountInfoDouble(ACCOUNT_BALANCE);
datetime startDate = TimeCurrent();
string Profit()
{
   string result = "";
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double profit = balance - accBal;
   double profitPercent = profit / accBal * 100;
   datetime endDate = TimeCurrent();
   int days = (int)(endDate - startDate) / 86400;
   int tradingDays = days * 5 / 7;
   double profitPerDay = profitPercent / tradingDays;
   double profitPerMonth = profitPerDay * 20;
   profitPercent = NormalizeDouble(profitPercent, 2);
   profitPerDay = NormalizeDouble(profitPerDay, 2);
   profitPerMonth = NormalizeDouble(profitPerMonth, 2);
   result = "Profit: " + (string)profitPercent + "%";
   if (tradingDays > 0)
      result += " | Profit per day: " + (string)profitPerDay + "%";
   if (tradingDays > 20)
      result += " | Profit per month: " + (string)profitPerMonth + "%";
   return result;
}

void Stats()
{
   string stats = "\n" + DrawDown() + "\n" + Profit() + "\n";
   stats += "\n" +
            "AUDUSD: " + (string)Volume("AUDUSD") + " | " + (string)AtrValue("AUDUSD") + "\n" +
            "EURUSD: " + (string)Volume("EURUSD") + " | " + (string)AtrValue("EURUSD") + "\n" +
            "GBPUSD: " + (string)Volume("GBPUSD") + " | " + (string)AtrValue("GBPUSD") + "\n" +
            "USDCAD: " + (string)Volume("USDCAD") + " | " + (string)AtrValue("USDCAD") + "\n" +
            "USDCHF: " + (string)Volume("USDCHF") + " | " + (string)AtrValue("USDCHF") + "\n" +
            "USDJPY: " + (string)Volume("USDJPY") + " | " + (string)AtrValue("USDJPY") + "\n" +
            "XAUUSD: " + (string)Volume("XAUUSD") + " | " + (string)AtrValue("XAUUSD") + "\n";
   // Comment(stats);
   // Print(stats);
}

void Plot()
{
   Stats();
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct economicNews
{
   MqlCalendarEvent event;
   MqlCalendarValue value;
   MqlCalendarCountry country;
};

void createEconomicNews(MqlCalendarEvent &event, MqlCalendarValue &value, MqlCalendarCountry &country, economicNews &nieuws)
{

   nieuws.value = value;
   nieuws.event = event;
   nieuws.country = country;
}

string newsToString(economicNews &nieuws)
{

   string strNews = "";
   strNews += ((string)nieuws.event.id + ";");
   strNews += ((string)nieuws.event.type + ";");
   strNews += ((string)nieuws.event.sector + ";");
   strNews += ((string)nieuws.event.frequency + ";");
   strNews += ((string)nieuws.event.time_mode + ";");
   strNews += ((string)nieuws.event.country_id + ";");
   strNews += ((string)nieuws.event.unit + ";");
   strNews += ((string)nieuws.event.importance + ";");
   strNews += ((string)nieuws.event.multiplier + ";");
   strNews += ((string)nieuws.event.digits + ";");
   strNews += (nieuws.event.source_url + ";");
   strNews += (nieuws.event.event_code + ";");
   strNews += (nieuws.event.name + ";");
   strNews += ((string)nieuws.value.id + ";");
   strNews += ((string)nieuws.value.event_id + ";");
   strNews += ((string)(long)nieuws.value.time + ";");
   strNews += ((string)(long)nieuws.value.period + ";");
   strNews += ((string)nieuws.value.revision + ";");
   strNews += ((string)nieuws.value.actual_value + ";");
   strNews += ((string)nieuws.value.prev_value + ";");
   strNews += ((string)nieuws.value.revised_prev_value + ";");
   strNews += ((string)nieuws.value.forecast_value + ";");
   strNews += ((string)nieuws.value.impact_type + ";");
   strNews += ((string)nieuws.country.id + ";");
   strNews += ((string)nieuws.country.name + ";");
   strNews += ((string)nieuws.country.code + ";");
   strNews += ((string)nieuws.country.currency + ";");
   strNews += ((string)nieuws.country.currency_symbol + ";");
   strNews += ((string)nieuws.country.url_name);

   return strNews;
}

bool stringToNews(string newsStr, economicNews &nieuws)
{

   string tokens[];

   if (StringSplit(newsStr, ';', tokens) == 29)
   {

      nieuws.event.id = (ulong)tokens[0];
      nieuws.event.type = (ENUM_CALENDAR_EVENT_TYPE)tokens[1];
      nieuws.event.sector = (ENUM_CALENDAR_EVENT_SECTOR)tokens[2];
      nieuws.event.frequency = (ENUM_CALENDAR_EVENT_FREQUENCY)tokens[3];
      nieuws.event.time_mode = (ENUM_CALENDAR_EVENT_TIMEMODE)tokens[4];
      nieuws.event.country_id = (ulong)tokens[5];
      nieuws.event.unit = (ENUM_CALENDAR_EVENT_UNIT)tokens[6];
      nieuws.event.importance = (ENUM_CALENDAR_EVENT_IMPORTANCE)tokens[7];
      nieuws.event.multiplier = (ENUM_CALENDAR_EVENT_MULTIPLIER)tokens[8];
      nieuws.event.digits = (uint)tokens[9];
      nieuws.event.source_url = tokens[10];
      nieuws.event.event_code = tokens[11];
      nieuws.event.name = tokens[12];
      nieuws.value.id = (ulong)tokens[13];
      nieuws.value.event_id = (ulong)tokens[14];
      nieuws.value.time = (datetime)(long)tokens[15];
      nieuws.value.period = (datetime)(long)tokens[16];
      nieuws.value.revision = (int)tokens[17];
      nieuws.value.actual_value = (long)tokens[18];
      nieuws.value.prev_value = (long)tokens[19];
      nieuws.value.revised_prev_value = (long)tokens[20];
      nieuws.value.forecast_value = (long)tokens[21];
      nieuws.value.impact_type = (ENUM_CALENDAR_EVENT_IMPACT)tokens[22];
      nieuws.country.id = (ulong)tokens[23];
      nieuws.country.name = tokens[24];
      nieuws.country.code = tokens[25];
      nieuws.country.currency = tokens[26];
      nieuws.country.currency_symbol = tokens[27];
      nieuws.country.url_name = tokens[28];

      return true;
   }

   return false;
}

void downloadNews()
{

   int fileHandle = FileOpen("news_" + ".csv", FILE_WRITE | FILE_COMMON);

   if (fileHandle != INVALID_HANDLE)
   {

      MqlCalendarValue values[];

      if (CalendarValueHistory(values, D'01.01.1970', TimeCurrent(), NULL, NULL))
      {

         for (int i = 0; i < ArraySize(values); i += 1)
         {

            MqlCalendarEvent event;

            if (CalendarEventById(values[i].event_id, event))
            {

               MqlCalendarCountry country;

               if (CalendarCountryById(event.country_id, country))
               {

                  economicNews nieuws;
                  createEconomicNews(event, values[i], country, nieuws);
                  FileWrite(fileHandle, newsToString(nieuws));
               }
            }
         }
      }
   }

   FileClose(fileHandle);

   Print("End of nieuws download ");
}

bool getBTnews(long period, economicNews &nieuws[])
{

   ArrayResize(nieuws, 0);
   int fileHandle = FileOpen("news_" + ".csv", FILE_READ | FILE_COMMON);

   if (fileHandle != INVALID_HANDLE)
   {

      while (!FileIsEnding(fileHandle))
      {

         economicNews n;
         if (stringToNews(FileReadString(fileHandle), n))
         {

            if (n.value.time < TimeCurrent() + period && n.value.time > TimeCurrent() - period)
            {

               ArrayResize(nieuws, ArraySize(nieuws) + 1);
               nieuws[ArraySize(nieuws) - 1] = n;
            }
         }
      }

      FileClose(fileHandle);
      return true;
   }

   FileClose(fileHandle);
   return false;
}

bool getBTnewsAll(economicNews &nieuws[])
{

   ArrayResize(nieuws, 0);
   int fileHandle = FileOpen("news_" + ".csv", FILE_READ | FILE_COMMON);

   if (fileHandle != INVALID_HANDLE)
   {

      while (!FileIsEnding(fileHandle))
      {

         economicNews n;
         if (stringToNews(FileReadString(fileHandle), n))
         {

            ArrayResize(nieuws, ArraySize(nieuws) + 1);
            nieuws[ArraySize(nieuws) - 1] = n;
         }
      }

      FileClose(fileHandle);
      return true;
   }

   FileClose(fileHandle);
   return false;
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

economicNews nieuwsTester[];

void OnTickTester()
{
   if (IsNewBarTester(PERIOD_M5))
   {
      IsNewsEvent();
      // Plot();
   }
   CheckTrades();
}

bool IsNewBarTester(ENUM_TIMEFRAMES timeFrame)
{
   static int barsTotalTester;
   int bars = iBars(Symbol(), timeFrame);
   if (bars > barsTotalTester)
   {
      barsTotalTester = bars;
      return true;
   }
   return false;
}

void IsNewsEventTester()
{
   datetime candleOpen = iTime(Symbol(), PERIOD_M5, 0);

   int amount = ArraySize(nieuwsTester);

   for (int i = amount - 1; i >= 0; i--)
   {

      MqlCalendarEvent event = nieuwsTester[i].event;
      MqlCalendarValue value = nieuwsTester[i].value;
      MqlCalendarCountry country = nieuwsTester[i].country;

      if (value.time != candleOpen)
         continue;
      Print("Time: ", value.time, " | CandleOpen: ", candleOpen);

      if (event.importance == CALENDAR_IMPORTANCE_NONE)
      {

         continue;
      }
      if (event.importance == CALENDAR_IMPORTANCE_LOW && !InpImportance_low)
      {

         continue;
      }
      if (event.importance == CALENDAR_IMPORTANCE_MODERATE && !InpImportance_moderate)
      {

         continue;
      }
      if (event.importance == CALENDAR_IMPORTANCE_HIGH && !InpImportance_high)
      {

         continue;
      }

      string currency = country.currency;
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
      {

         continue;
      }

      ENUM_CALENDAR_EVENT_IMPACT newsImpact = value.impact_type;

      string msg = currency + (newsImpact == CALENDAR_IMPACT_POSITIVE ? "+ " : "- ") + event.name + " " + (string)event.importance;
      bool isBuy = (currency == margin && newsImpact == CALENDAR_IMPACT_POSITIVE) ||
                   (currency != margin && newsImpact == CALENDAR_IMPACT_NEGATIVE);

      if (value.actual_value == value.forecast_value || value.actual_value == value.prev_value)
      {

         continue;
      }

      if (event.importance == CALENDAR_IMPORTANCE_MODERATE)
         executeTrade(symbol, isBuy, msg, 2);
      else
         executeTrade(symbol, isBuy, msg);
      Print(msg);
      ArrayRemove(nieuwsTester, i);
   }
}

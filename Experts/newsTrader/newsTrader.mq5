
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com/en/market/product/113923"
#property version "1.00"
#property description "This EA is designed to trade news events based on the economic calendar."

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= Risk settings =========";
long InpMagicNumber = 888; // Magic

enum RISK_MODE_ENUM
{
   RISK_MODE_1, // Safe
   RISK_MODE_2, // Cautious
   RISK_MODE_3, // Low
   RISK_MODE_4, // Moderate
   RISK_MODE_5, // High
   RISK_MODE_6, // Extreme
   RISK_MODE_7, // Aggressive
   RISK_MODE_8, // Kamikaze
};
input RISK_MODE_ENUM InpRiskMode = RISK_MODE_7; // Risk mode
double InpRisk;

input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_H4; // Stop timeframe

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

input group "========= News importance =========";
input bool InpImportance_low = false;     // low
input bool InpImportance_moderate = true; // moderate
input bool InpImportance_high = true;     // high

ENUM_TIMEFRAMES calendarTime = PERIOD_D1;
MqlCalendarValue hist[];
MqlCalendarValue news[];

int handleAtr;
double bufferAtr[];

int OnInit()
{
   string symbols[] = {"AUDUSD", "EURUSD", "GBPUSD", "USDCAD", "USDCHF", "USDJPY", "XAUUSD"};
   string missingSymbols[];
   for (int i = 0; i < ArraySize(symbols); i++)
   {
      if (!SymbolSelect(symbols[i], true))
      {
         ArrayResize(missingSymbols, ArraySize(missingSymbols) + 1);
         missingSymbols[ArraySize(missingSymbols) - 1] = symbols[i];
      }
   }
   if (ArraySize(missingSymbols) > 0)
   {
      string msg = "Please add the missing symbols to market watch first > Missing symbols: ";
      for (int i = 0; i < ArraySize(missingSymbols); i++)
      {
         msg += missingSymbols[i] + (i < ArraySize(missingSymbols) - 1 ? ", " : "");
      }
      Print(msg);
      ExpertRemove();
      return INIT_FAILED;
   }

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
   Print("News Trader running successfully");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Comment("");
}

void OnTick()
{
   IsNewsEvent();
   CheckTrades();

   if (IsNewBar(calendarTime))
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

double Volume(string symbol, int volDivider = 1)
{
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
      Print(atr, " > Failed to get ATR value, sending minVol: ", minVol);
      return minVol;
   }
   else if (lots < minVol)
   {
      Print(lots, " > Adjusted to minimum volume > ", minVol);
      return minVol;
   }
   else if (lots > maxVol)
   {
      Print(lots, " > Adjusted to maximum volume > ", maxVol);
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
   datetime startTime = iTime(Symbol(), calendarTime, 0);
   datetime endTime = startTime + PeriodSeconds(calendarTime);
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
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double newStopLoss = 0;

      if (multiplier < 1)
         continue;

      if (positionType == POSITION_TYPE_BUY && currentPrice > entryPrice)
      {
         newStopLoss = Normalize(symbol, entryPrice + (trail * (multiplier - 1)) + point);
      }
      else if (positionType == POSITION_TYPE_SELL && currentPrice < entryPrice)
      {
         newStopLoss = Normalize(symbol, entryPrice - (trail * (multiplier - 1)) - point);
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

double balanceHigh;
double maxDrawdown;
string DrawDown()
{
   string result = "";
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if (currentBalance > balanceHigh)
      balanceHigh = currentBalance;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = 100 - equity / balanceHigh * 100;
   if (drawdown > maxDrawdown)
      maxDrawdown = drawdown;
   maxDrawdown = NormalizeDouble(maxDrawdown, 2);
   if (maxDrawdown == 0)
      return result;
   return "Drawdown: " + (string)maxDrawdown + "%";
   return result;
}

datetime startDate = TimeCurrent();
double startBalance = AccountInfoDouble(ACCOUNT_BALANCE);

string Profit()
{
   string result = "";
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double profit = currentBalance - startBalance;
   double profitPercent = profit / startBalance * 100;
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
   Comment(stats);
}

void Plot()
{
   Stats();
}

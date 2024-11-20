// high frequency trading. open a trade in direction of last candle open/close with sl atr value. when trade hits sl or tp open a new trade in that direction. parameters: magic number, risk value, risk type, risk value amount, atr timeframe, atr periods, symbols input, risk reward ratio, start trading hour, stop trading hour, max spread
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade/Trade.mqh>
#include <Arrays/ArrayLong.mqh>
#include <Arrays/ArrayObj.mqh>

class CSymbol : public CObject
{
   public:
      CSymbol(string name) : symbol(name) {};
      ~CSymbol() {};
   
      string symbol;
      int handleAtr;
      double lastPrice;
};

CArrayObj symbols;

enum ENUM_SYMBOLS
{
   SYMBOLS_ALL,
   SYMBOLS_MAJOR,
   SYMBOLS_EURUSD,
   SYMBOLS_AUDUSD,
   SYMBOLS_GBPUSD,
   SYMBOLS_USDCAD,
   SYMBOLS_USDCHF,
   SYMBOLS_USDJPY,
   SYMBOLS_MINOR,
};
input ENUM_SYMBOLS InpSymbols = SYMBOLS_ALL;    // symbols
enum ENUM_RISK_VALUE
{
   RISK_VALUE_LOT,
   RISK_VALUE_PERCENT
};
input ENUM_RISK_VALUE InpRiskValue = RISK_VALUE_PERCENT; // risk value
enum ENUM_RISK_TYPE
{
   RISK_TYPE_BALANCE,
   RISK_TYPE_EQUITY,
   RISK_TYPE_STATIC
};
input ENUM_RISK_TYPE InpRiskType = RISK_TYPE_BALANCE;
input double InpRiskValueAmount = 1.0; // risk value amount
input double InpRiskRewardRatio = 1.0; // risk reward ratio
input int InpAtrPeriods = 14; // ATR period to determine range
input int InpAtrFilter = 0; // atr filter (0=off)
input ENUM_TIMEFRAMES InpAtrTimeframe = PERIOD_CURRENT; // ATR timeframe
input int InpMagic = 8; // magic number
input int InpStartTradingHour = 0; // start trading hour server time (0=off)
input int InpStopTradingHour = 0; // stop trading hour server time (0=off)
input int InpMaxSpread = 0; // max spread allowed (0=off)
input bool InpSwitch = true;

int OnInit()
{
   string arrSymbols[];
   if (InpSymbols == SYMBOLS_MAJOR)
   {
      ArrayResize(arrSymbols, 6);
      arrSymbols[0] = "EURUSD";
      arrSymbols[1] = "USDJPY";
      arrSymbols[2] = "GBPUSD";
      arrSymbols[3] = "AUDUSD";
      arrSymbols[4] = "USDCAD";
      arrSymbols[5] = "USDCHF";
   }
   else if (InpSymbols == SYMBOLS_MINOR)
   {
      ArrayResize(arrSymbols, 20);
      arrSymbols[0] = "AUDCHF";
      arrSymbols[1] = "AUDJPY";
      arrSymbols[2] = "AUDNZD";
      arrSymbols[3] = "CADCHF";
      arrSymbols[4] = "CADJPY";
      arrSymbols[5] = "CHFJPY";
      arrSymbols[6] = "EURAUD";
      arrSymbols[7] = "EURCAD";
      arrSymbols[8] = "EURCHF";
      arrSymbols[9] = "EURGBP";
      arrSymbols[10] = "AUDCAD";
      arrSymbols[11] = "EURJPY";
      arrSymbols[12] = "USDSGD";
      arrSymbols[13] = "EURNZD";
      arrSymbols[14] = "GBPAUD";
      arrSymbols[15] = "GBPCAD";
      arrSymbols[16] = "GBPCHF";
      arrSymbols[17] = "GBPJPY";
      arrSymbols[18] = "GBPNZD";
      arrSymbols[19] = "NZDCAD";
   }
   else if (InpSymbols == SYMBOLS_ALL)
   {
      ArrayResize(arrSymbols, 26);
      arrSymbols[0] = "EURUSD";
      arrSymbols[1] = "USDJPY";
      arrSymbols[2] = "GBPUSD";
      arrSymbols[3] = "AUDUSD";
      arrSymbols[4] = "USDCAD";
      arrSymbols[5] = "USDCHF";
      arrSymbols[6] = "AUDCHF";
      arrSymbols[7] = "AUDJPY";
      arrSymbols[8] = "AUDNZD";
      arrSymbols[9] = "CADCHF";
      arrSymbols[10] = "CADJPY";
      arrSymbols[11] = "CHFJPY";
      arrSymbols[12] = "EURAUD";
      arrSymbols[13] = "EURCAD";
      arrSymbols[14] = "EURCHF";
      arrSymbols[15] = "EURGBP";
      arrSymbols[16] = "AUDCAD";
      arrSymbols[17] = "EURJPY";
      arrSymbols[18] = "USDSGD";
      arrSymbols[19] = "EURNZD";
      arrSymbols[20] = "GBPAUD";
      arrSymbols[21] = "GBPCAD";
      arrSymbols[22] = "GBPCHF";
      arrSymbols[23] = "GBPJPY";
      arrSymbols[24] = "GBPNZD";
      arrSymbols[25] = "NZDCAD";
   }
   else if (InpSymbols == SYMBOLS_EURUSD)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "EURUSD";
   }
   else if (InpSymbols == SYMBOLS_USDJPY)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "USDJPY";
   }
   else if (InpSymbols == SYMBOLS_GBPUSD)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "GBPUSD";
   }
   else if (InpSymbols == SYMBOLS_AUDUSD)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "AUDUSD";
   }
   else if (InpSymbols == SYMBOLS_USDCAD)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "USDCAD";
   }
   else if (InpSymbols == SYMBOLS_USDCHF)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "USDCHF";
   }

   symbols.Clear();
   for (int i = ArraySize(arrSymbols) - 1; i >= 0; i--)
   {
      CSymbol *symbol = new CSymbol(arrSymbols[i]);
      symbol.handleAtr = iATR(symbol.symbol, InpAtrTimeframe, InpAtrPeriods);
      symbols.Add(symbol);
   }
   
   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
   MqlDateTime dt;
   TimeCurrent(dt);

    for (int j = symbols.Total() - 1; j >= 0; j--)
    {
        CSymbol *symbol = symbols.At(j);

        CTrade trade;
        trade.SetExpertMagicNumber(InpMagic);

        string sym = symbol.symbol;
        double atr[];
        CopyBuffer(symbol.handleAtr, MAIN_LINE, 0,InpAtrFilter+1, atr);
        double sl = atr[0];
        double tp = sl * InpRiskRewardRatio;
        double lot = Volume(sym, sl);

        double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
        double bid = SymbolInfoDouble(sym, SYMBOL_BID);

        int positionCount = 0;
         for (int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == sym && PositionGetInteger(POSITION_MAGIC) == InpMagic)
            {
               positionCount++;
               symbol.lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            }
         }
         double lastPrice = symbol.lastPrice;

        if (((InpAtrFilter > 0? atr[0] <= atr[InpAtrFilter-1]:false) || (InpMaxSpread > 0 && SymbolInfoInteger(sym, SYMBOL_SPREAD) > InpMaxSpread) || (InpStartTradingHour > 0 && dt.hour < InpStartTradingHour) || (InpStopTradingHour > 0 && dt.hour > InpStopTradingHour)) && positionCount==0) {
         //Comment("no trading allowed due to spread or server time.");
         symbol.lastPrice = 0;
         continue;
        }

         if (positionCount == 0)
         {
               if (ask > lastPrice && lastPrice > 0)
                {
                      if(InpSwitch) trade.Sell(lot, sym, bid, bid+sl, bid-tp);
                     else trade.Buy(lot, sym, ask, ask-sl, ask+tp);
                }
                else if (bid < lastPrice && lastPrice > 0)
                {
                     if(InpSwitch) trade.Buy(lot, sym, ask, ask-sl, ask+tp);
                     else trade.Sell(lot, sym, bid, bid+sl, bid-tp);
                }
               else if (ask > iOpen(sym, InpAtrTimeframe, 0))
               {
                     if(InpSwitch) trade.Sell(lot, sym, bid, bid+sl, bid-tp);
                     else trade.Buy(lot, sym, ask, ask-sl, ask+tp);
               }
               else if (bid < iOpen(sym, InpAtrTimeframe, 0))
               {
                     if(InpSwitch) trade.Buy(lot, sym, ask, ask-sl, ask+tp);
                     else trade.Sell(lot, sym, bid, bid+sl, bid-tp);
               }
         }
    }
}

double capital = AccountInfoDouble(ACCOUNT_BALANCE);
double Volume(string sym, double distance)
{
   if (InpRiskValue == RISK_VALUE_LOT)
      return InpRiskValueAmount;

   if (InpRiskType == RISK_TYPE_BALANCE)
      capital = AccountInfoDouble(ACCOUNT_BALANCE);
   else if (InpRiskType == RISK_TYPE_EQUITY)
      capital = AccountInfoDouble(ACCOUNT_EQUITY);

   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   double riskMoney = capital * InpRiskValueAmount / 100;
   double moneyLotStep = distance / tickSize * tickValue * lotStep;

   double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;

   double minVol = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);

   if (lots < minVol)
      return minVol;

   else if (lots > maxVol)
      return maxVol;

   return lots;
}

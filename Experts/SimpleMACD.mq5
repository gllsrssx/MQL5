#include <Trade\Trade.mqh>
CTrade trade;

// Input parameters
input group "general";
input long InpMagicNumber = 12345678; // Magic Number
input group "risk";
input double InpRisk = 1.0;       // Risk percentage per trade
input double InpRiskReward = 1.0; // Risk reward ratio
input group "ATR";
input double ATRMultiplier = 1.0;                    // ATR multiplier
input int ATRPeriod = 500;                           // ATR period
input ENUM_APPLIED_PRICE ATRPrice = PRICE_CLOSE;     // ATR price
input ENUM_TIMEFRAMES ATRTimeframe = PERIOD_CURRENT; // ATR timeframe
input group "MA";
input int MAPeriod = 120;                           // MA period
input ENUM_MA_METHOD MAMethod = MODE_EMA;           // MA method
input ENUM_APPLIED_PRICE MAPrice = PRICE_CLOSE;     // MA price
input ENUM_TIMEFRAMES MATimeframe = PERIOD_CURRENT; // MA timeframe
input group "MACD";
input int hLine = 25;                                 // Horizontal line minimum value
input int MACDFast = 12;                              // MACD fast EMA period
input int MACDSlow = 26;                              // MACD slow EMA period
input int MACDSignal = 9;                             // MACD signal line period
input ENUM_APPLIED_PRICE MACDPrice = PRICE_CLOSE;     // MACD price
input ENUM_TIMEFRAMES MACDTimeframe = PERIOD_CURRENT; // MACD timeframe
enum MACD_ENTRY
{
  MACD_REVERSAL,
  MACD_CONTINUATION,
  MACD_HISTOGRAM
};
input MACD_ENTRY MACDEntry = MACD_REVERSAL; // MACD entry type
input group "Time";
input int InpStartHour = 2; // Start trading hour
input int InpEndHour = 22;  // End trading hour
input group "Direction";
input bool InpLong = true;  // Trade long
input bool InpShort = true; // Trade short
input group "Plot";
input bool PlotIndicator = true; // Plot indicator
input bool PlotEntry = true;     // Plot entry
input bool PlotInfo = true;      // Plot info
input bool PlotComment = true;   // Plot comment

// Global variables
MqlTick tick;
MqlDateTime time;

string symbolName = Symbol();
double maxlot = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MAX);
double minVol = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MIN);
double maxVol = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MAX);
double tickSize = SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_SIZE);
double tickValue = SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_VALUE);
double lotStep = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_STEP);
int atrHandle, maHandle, macdHandle, signalHandle;

int OnInit()
{
  if (TimeCurrent() > StringToTime("2025.01.01 00:00:00") && !MQLInfoInteger(MQL_TESTER))
  {
    Print("INFO: This is a demo version of the EA. It will only work until January 1, 2025.");
    ExpertRemove();
  }

  atrHandle = iATR(symbolName, ATRTimeframe, ATRPeriod);
  maHandle = iMA(symbolName, MATimeframe, MAPeriod, 0, MAMethod, MAPrice);
  macdHandle = iMACD(symbolName, MACDTimeframe, MACDFast, MACDSlow, MACDSignal, MACDPrice);

  trade.SetExpertMagicNumber(InpMagicNumber);
  Comment("EA initialized successfully");
  return INIT_SUCCEEDED;
}

void OnTick()
{
  TimeToStruct(TimeCurrent(), time);
  SymbolInfoTick(symbolName, tick);
  TakeTrade();
  Plot();
}

bool IsNewBar(ENUM_TIMEFRAMES timeframe, int &barsTotal)
{
  int bars = iBars(symbolName, timeframe);
  if (bars == barsTotal)
    return false;
  barsTotal = bars;
  return true;
}

int PositionCount()
{
  int count = 0;
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (!PositionSelectByTicket(ticket))
      continue;
    if (PositionGetString(POSITION_SYMBOL) != symbolName || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetDouble(POSITION_VOLUME) == maxVol)
      continue;
    count++;
  }
  return count;
}

double ATR()
{
  double atrBuffer[];
  ArraySetAsSeries(atrBuffer, true);
  CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
  return atrBuffer[0] * ATRMultiplier;
}

double MA()
{
  double maBuffer[];
  ArraySetAsSeries(maBuffer, true);
  CopyBuffer(maHandle, 0, 0, 1, maBuffer);
  return maBuffer[0];
}

double MACDcalculator(bool TrueForHistogram_FalseForSignal, int shift = 0)
{
  int maxBars = 500;

  // Creating an array for prices for MACD main line, MACD signal line
  double MACDMainLine[];
  double MACDSignalLine[];

  // Defining MACD and its parameters
  int MACDDef = iMACD(symbolName, MACDTimeframe, MACDFast, MACDSlow, MACDSignal, MACDPrice);

  // Sorting price array from current data for MACD main line, MACD signal line
  ArraySetAsSeries(MACDMainLine, true);
  ArraySetAsSeries(MACDSignalLine, true);

  // Storing results after defining MA, line, current data for MACD main line, MACD signal line
  CopyBuffer(MACDDef, 0, 0, maxBars, MACDMainLine);
  CopyBuffer(MACDDef, 1, 0, maxBars, MACDSignalLine);

  // Get values of current data for MACD main line, MACD signal line
  double MACDMainLineVal = NormalizeDouble(MACDMainLine[shift], 6);
  double MACDSignalLineVal = NormalizeDouble(MACDSignalLine[shift], 6);

  // Calculate the maximum absolute value for scaling
  double maxAbsValue = 0;
  for (int i = 0; i < maxBars; i++)
  {
    if (MathAbs(MACDMainLine[i]) > maxAbsValue)
      maxAbsValue = MathAbs(MACDMainLine[i]);
    if (MathAbs(MACDSignalLine[i]) > maxAbsValue)
      maxAbsValue = MathAbs(MACDSignalLine[i]);
  }

  // Scale the values to be between -100 and +100
  if (maxAbsValue != 0)
  {
    MACDMainLineVal = (MACDMainLineVal / maxAbsValue) * 100;
    MACDSignalLineVal = (MACDSignalLineVal / maxAbsValue) * 100;
  }

  if (TrueForHistogram_FalseForSignal)
  {
    return MACDMainLineVal;
  }
  else
  {
    return MACDSignalLineVal;
  }
}

int MACDSignal()
{
  double macdMain = MACDcalculator(true, 0);
  double macdSignal = MACDcalculator(false, 0);
  double macdMainPrev = MACDcalculator(true, 1);
  double macdSignalPrev = MACDcalculator(false, 1);

  if (MathAbs(macdMain) < hLine && MathAbs(macdSignal) < hLine)
    return 0;

  if (macdMain > macdSignal && macdMainPrev < macdSignalPrev)
    return 1;
  else if (macdMain < macdSignal && macdMainPrev > macdSignalPrev)
    return -1;

  return 0;
}

int MASignal()
{
  double maValue = MA();
  if (tick.ask > maValue)
    return 1;
  else if (tick.bid < maValue)
    return -1;
  return 0;
}

double Volume()
{
  double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRisk * 0.01;
  double moneyLotStep = ATR() / tickSize * tickValue * lotStep;
  double lots = MathRound(riskMoney / moneyLotStep) * lotStep;
  if (lots < minVol || lots == NULL)
    lots = minVol;
  else if (lots == maxVol)
    lots -= lotStep;
  return lots;
}

int barsTotalTrade;
void TakeTrade()
{
  if (PositionCount() > 0 || time.hour < InpStartHour || time.hour > InpEndHour || !IsNewBar(PERIOD_M1, barsTotalTrade))
    return;
  int macdSignal = MACDSignal();
  int maSignal = MASignal();
  if (macdSignal == 0 && maSignal != macdSignal)
    return;
  double stopPoints = ATR();
  double profitPoints = stopPoints * InpRiskReward;
  double lots = Volume();
  double maValue = MA();

  if (macdSignal == 1 && InpLong && tick.ask > maValue && InpLong)
  {
    while (lots > 0)
    {
      trade.Buy(NormalizeDouble(lots > maxlot ? maxlot : lots, 2), NULL, 0, tick.ask - stopPoints, tick.ask + profitPoints, "MACD Buy");
      lots -= maxlot;
    }
  }
  else if (macdSignal == -1 && InpShort && tick.bid < maValue && InpShort)
  {
    while (lots > 0)
    {
      trade.Sell(NormalizeDouble(lots > maxlot ? maxlot : lots, 2), NULL, 0, tick.bid + stopPoints, tick.bid - profitPoints, "MACD Sell");
      lots -= maxlot;
    }
  }
}

// Plot
void Plot()
{
  int macdPlot = (int)MACDcalculator(true, 0);
  int signalPlot = (int)MACDcalculator(false, 0);
  double maPlot = MASignal();
  Comment("MA: ", maPlot, " MACD: ", macdPlot, " Signal: ", signalPlot);
}
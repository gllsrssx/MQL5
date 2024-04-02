
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

// Define the indicator and input parameters
input group "========= Risk settings =========";
input double riskPercent = 0.1; // risk percent
input bool takeBuys = false;    // take buys
input bool takeSells = false;   // take sells
input group "========= MA settings =========";
input int maPeriod = 120;               // ma period
input int maDivider = 5;                // ma divider
input ENUM_MA_METHOD maMode = MODE_EMA; // ma mode
// PRICE_OPEN
input ENUM_APPLIED_PRICE maPrice = PRICE_CLOSE; // applied price

double currentPrice;
double bid, ask, spread;

int barsTotal;

// Define handles
int maHandle;

int maDirection = 0;
int lastMaDirection = 0;
int periodSinceLastDirectionChange = 0;
datetime previousTime = TimeCurrent();

int symbolPosCount = 0;

// Define the OnInit function
int OnInit()
{
    barsTotal = iBars(Symbol(), PERIOD_CURRENT);

    if (maPeriod > 0)
        maHandle = iMA(Symbol(), PERIOD_CURRENT, maPeriod, 0, maMode, maPrice);

    return (INIT_SUCCEEDED);
}

// Define the OnDeinit function, make it delete all objects created by the indicator and close all orders
void OnDeinit(const int reason)
{

    for (int j = 0; j < OrdersTotal(); j++)
    {
        if (OrderGetTicket(j))
        {
            trade.OrderDelete(OrderGetTicket(j));
        }
    }
}

// Define the OnTick function
void OnTick()
{
    bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    currentPrice = NormalizeDouble((ask + bid) / 2, Digits());
    spread = NormalizeDouble(MathAbs(ask - bid), Digits());

    Ema();

    if (maDirection > 0 && PositionsTotal() == 0 && takeBuys)
    {
        trade.Buy(riskPercent);
    }

    if (maDirection < 0 && PositionsTotal() == 0 && takeSells)
    {
        trade.Sell(riskPercent);
    }

    if (maDirection == 0)
    {
        CloseThisSymbolAll();
    }
}

void Ema()
{
    int bars = iBars(Symbol(), PERIOD_CURRENT);

    if (barsTotal < bars)
    {
        barsTotal = bars;

        double ma[];
        ArraySetAsSeries(ma, true);
        CopyBuffer(maHandle, MAIN_LINE, 0, barsTotal, ma);

        int newMaDirection = 0;
        if (currentPrice > ma[0])
            newMaDirection = 1;
        else if (currentPrice < ma[0])
            newMaDirection = -1;
        else
            newMaDirection = 0;

        if (newMaDirection != lastMaDirection)
        {
            periodSinceLastDirectionChange = 1;
            lastMaDirection = newMaDirection;
        }
        else
        {
            periodSinceLastDirectionChange++;
        }

        int changePeriod = (int)MathRound(maPeriod / maDivider);
        if (periodSinceLastDirectionChange >= changePeriod)
        {
            maDirection = newMaDirection;
        }
        else
        {
            maDirection = 0;
        }

        ObjectCreate(0, "Ma " + (string)previousTime, OBJ_TREND, 0, TimeCurrent(), ma[0], previousTime, ma[1]);
        ObjectSetInteger(0, "Ma " + (string)previousTime, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, "Ma " + (string)previousTime, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, "Ma " + (string)previousTime, OBJPROP_COLOR, maDirection > 0 ? clrGreen : maDirection < 0 ? clrRed
                                                                                                                      : clrYellow);

        previousTime = TimeCurrent();
    }
}

void CloseThisSymbolAll()
{
    int positions, orders;
    ulong inpMagic = 0;
    ulong ticket = PositionGetInteger(POSITION_TICKET);
    int orderType = (int)PositionGetInteger(POSITION_TYPE);
    int orderPendingType = (int)OrderGetInteger(ORDER_TYPE);
    string orderSymbol = PositionGetString(POSITION_SYMBOL);
    string orderPendingSymbol = OrderGetString(ORDER_SYMBOL);
    ulong orderPendingTicket = OrderGetInteger(ORDER_TICKET);
    ulong orderMagicNumber = PositionGetInteger(POSITION_MAGIC);
    ulong orderPendingMagicNumber = OrderGetInteger(ORDER_MAGIC);

    for (orders = OrdersTotal() - 1, positions = PositionsTotal() - 1; positions >= 0 || orders >= 0; positions--, orders--)
    {
        ulong numTicket = PositionGetTicket(positions);
        ulong numOrderTicket = OrderGetTicket(orders);

        if (orderType == POSITION_TYPE_BUY)
        {
            trade.PositionClose(numTicket);
        }
        if (orderType == POSITION_TYPE_SELL)
        {
            trade.PositionClose(numTicket);
        }
        if (orderPendingType == ORDER_TYPE_BUY_LIMIT || orderPendingType == ORDER_TYPE_SELL_LIMIT ||
            orderPendingType == ORDER_TYPE_BUY_STOP || orderPendingType == ORDER_TYPE_SELL_STOP || orderPendingType == ORDER_TYPE_BUY_STOP_LIMIT || orderPendingType == ORDER_TYPE_SELL_STOP_LIMIT)
        {
            trade.OrderDelete(numOrderTicket);
        }
    }
}

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
MqlTick lastTick;

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
    SymbolInfoTick(Symbol(), lastTick);

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
    if (maPeriod <= 0)
        return;

    static int barsTotal;
    int bars = iBars(Symbol(), Period());
    if (barsTotal >= bars)
        return;
    barsTotal = bars;

    double ma[];
    ArraySetAsSeries(ma, true);
    CopyBuffer(maHandle, MAIN_LINE, 0, barsTotal, ma);

    double high = iHigh(Symbol(), 0, 1);
    double low = iLow(Symbol(), 0, 1);

    int newMaDirection = 0;
    if (low > ma[0])
        newMaDirection = 1;
    else if (high < ma[0])
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

    int changePeriod = 24;
    if (periodSinceLastDirectionChange >= changePeriod)
    {
        maDirection = newMaDirection;
    }
    else
    {
        maDirection = 0;
    }

    // draw ma
    ObjectCreate(0, "Ma " + (string)TimeCurrent(), OBJ_TREND, 0, TimeCurrent(), ma[0], iTime(NULL, Period(), 1), ma[1]);
    ObjectSetInteger(0, "Ma " + (string)TimeCurrent(), OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "Ma " + (string)TimeCurrent(), OBJPROP_WIDTH, 4);
    ObjectSetInteger(0, "Ma " + (string)TimeCurrent(), OBJPROP_BACK, true);
    ObjectSetInteger(0, "Ma " + (string)TimeCurrent(), OBJPROP_COLOR, maDirection == 1 ? clrGreen : maDirection == -1 ? clrRed
                                                                                                                      : clrGold);

    ChartRedraw();
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
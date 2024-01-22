#property description "Exponential Moving Average"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots 1
#property indicator_label1 "EMA"
#property indicator_type1 DRAW_COLOR_LINE
#property indicator_color1 clrYellow,clrGreen,clrRed
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1

input int inpPeriod = 480;
ENUM_APPLIED_PRICE inpPrice = PRICE_CLOSE;

double val[],valc[];

int OnInit() {
   SetIndexBuffer(0,val,INDICATOR_DATA);
   SetIndexBuffer(1,valc,INDICATOR_COLOR_INDEX);
   IndicatorSetString(INDICATOR_SHORTNAME,"EMA ("+(string)inpPeriod+")");
   return (INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]) {
   int i = prev_calculated > 1 ? prev_calculated - 1 : 0;
   for (; i < rates_total && !_StopFlag; i++) {
      val[i] = i > 0 ? val[i-1] + 2.0 / (1.0 + inpPeriod) * (close[i] - val[i-1]) : close[i];
      if (i >= 50) {
         bool isBull = true;
         bool isBear = true;
         for (int j = 5; j <= 50; j += 5) {
            if (close[i-j] <= val[i-j]) isBull = false;
            if (close[i-j] >= val[i-j]) isBear = false;
         }
         if (close[i] <= val[i]) isBull = false;
         if (close[i] >= val[i]) isBear = false;
         valc[i] = isBull ? 1 : isBear ? 2 : 0;
      } else {
         valc[i] = EMPTY_VALUE;
      }
   }
   return (i);
}
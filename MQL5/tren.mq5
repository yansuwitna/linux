//+------------------------------------------------------------------+
//|                        AutoCandleInfoEA.mq5                      |
//|      Membaca n candlestick sebelumnya pada timeframe tertentu    |
//|      dan update otomatis di chart menggunakan OnTick()          |
//+------------------------------------------------------------------+
#property strict

input ENUM_TIMEFRAMES Timeframe = PERIOD_M1; // Timeframe candle yang dibaca//---
input int JumlahCandle = 2;                  // Jumlah candle sebelumnya yang ditampilkan

input double LotSize = 0.01;
input double TakeProfit = 50;
input double StopLoss = 30;

//===================================
input int Slippage = 10;
input ulong MagicNumber = 445566;

// Fungsi utama EA: dipanggil setiap tick
void OnTick()
{
   // Mengambil informasi akun
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
   double accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double accountProfit = AccountInfoDouble(ACCOUNT_PROFIT);

   // Mengambil harga Ask dan Bid
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double tp_buy = ask + TakeProfit * _Point;
   double tp_sell = bid - TakeProfit * _Point;
   
   double sl_buy = ask - StopLoss * _Point;
   double sl_sell = bid + StopLoss * _Point;
   
   int jml_naik = 0;
   int jml_turun = 0;
   
   int jml_posisi = 0;
   
   double posisi_clouse = 0;

   // Hitung jumlah posisi aktif BUY dan SELL dengan magic number EA ini
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) > 0 &&
          PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber)
      {
         int type = (int)PositionGetInteger(POSITION_TYPE);
         if (type == POSITION_TYPE_BUY){
            jml_posisi++;
         }else if (type == POSITION_TYPE_SELL){
            jml_posisi++;
         }
      }
      
   }
   
   
   if (JumlahCandle <= 0)
   {
      Comment("Jumlah candle harus lebih dari 0.");
      return;
   }

   string teks = StringFormat("%d Candlestick Sebelumnya (%s):\n\n", JumlahCandle, EnumToString(Timeframe));

   double jml_selisih = 0;
   
   for (int i = JumlahCandle; i >= 1; i--)
   {
      datetime t = iTime(_Symbol, Timeframe, i);
      double o = iOpen(_Symbol, Timeframe, i);
      double h = iHigh(_Symbol, Timeframe, i);
      double l = iLow(_Symbol, Timeframe, i);
      double c = iClose(_Symbol, Timeframe, i);
      posisi_clouse = c;

      teks += StringFormat("Candle [%d] - %s\nOpen: %.5f  High: %.5f  Low: %.5f  Close: %.5f\n",
                           i, TimeToString(t, TIME_DATE | TIME_MINUTES), o, h, l, c);
                           
      // Hitung selisih antara close dan open
      double selisih = c - o;
      jml_selisih += selisih;

      // Tentukan apakah naik atau turun
      string kondisi = "";
      
      if(selisih > 0){
         kondisi = "Naik" ;
         jml_naik++;
      }else{
         kondisi = "Turun";
         jml_turun++;
      };
      
      teks += StringFormat("Status : %s\n", kondisi);
      teks += StringFormat("Selisih : %.0f\n\n", selisih / _Point);
   }

   teks += StringFormat("JML Selisih : %.0f\n", jml_selisih / _Point);
   
   string kesimpulan = "";
   
  
   
   if(jml_posisi == 0){
      if(jml_naik == JumlahCandle && posisi_clouse > bid){
         OpenBuy(ask, tp_buy, sl_buy);
         kesimpulan = "BUY";
      }else if(jml_turun == JumlahCandle && posisi_clouse < ask){
         OpenSell(bid, tp_sell, sl_sell);
         kesimpulan = "SELL";
      }else{
         kesimpulan = "ANALISIS";
      }
   }
   
   teks += StringFormat("Kesimpulan : %s\n\n", kesimpulan);
   teks += StringFormat("Jumlah posisi trading terbuka: %d\n\n", jml_posisi);
   
   teks += "Equity: " + DoubleToString(accountEquity, 2) + "\n" +
              "Balance: " + DoubleToString(accountBalance, 2) + "\n" +
              "Margin: " + DoubleToString(accountMargin, 2) + "\n" +
              "Free Margin: " + DoubleToString(accountFreeMargin, 2) + "\n" +
              "Profit: " + DoubleToString(accountProfit, 2) + "\n\n" +
              
              "Lot Size: " + DoubleToString(LotSize, 2) + "\n" +
              "Take Profit: " + DoubleToString(TakeProfit, 0) + " pip\n" +
              "Stop Loss: " + DoubleToString(StopLoss, 0) + " pip\n";
              "Potongan: " + DoubleToString(ask-bid, 0) + " pip\n";
   
   Comment(teks); // Tampilkan di chart
}


//+------------------------------------------------------------------+
//| Fungsi membuka posisi BUY                                       |
//+------------------------------------------------------------------+
void OpenBuy(double ask, double tp, double sl)
{

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = sl; // SET SL
   request.tp = tp;
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = "AutoBuy";

   OrderSend(request, result);
}

void OpenSell(double bid, double tp, double sl)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.tp = tp;
   request.sl = sl; // SET SL
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = "AutoBuy";

   OrderSend(request, result);
}
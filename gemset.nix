{
  addressable = {
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0mpn7sbjl477h56gmxsjqb89r5s3w7vx5af994ssgc3iamvgzgvs";
      type = "gem";
    };
    version = "2.4.0";
  };
  byebug = {
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "18sdnscwwm76i2kbcib2ckwfwpq8b1dbfr97gdcx3j1x547yqv9x";
      type = "gem";
    };
    version = "9.0.5";
  };
  coderay = {
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1x6z923iwr1hi04k6kz5a6llrixflz8h5sskl9mhaaxy9jx2x93r";
      type = "gem";
    };
    version = "1.1.1";
  };
  crack = {
    dependencies = ["safe_yaml"];
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0abb0fvgw00akyik1zxnq7yv391va148151qxdghnzngv66bl62k";
      type = "gem";
    };
    version = "0.4.3";
  };
  domain_name = {
    dependencies = ["unf"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1fchfvk9wyifpb73hyyp5ykdn48hsa68c4rl44mk42qx5xriic5g";
      type = "gem";
    };
    version = "0.5.20160615";
  };
  hashdiff = {
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1r06gar8zp4hyzyc0ky7n6mybjj542lrfda5y78fm5hyhiplv104";
      type = "gem";
    };
    version = "0.3.0";
  };
  hashie = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "08w9ask37zh5w989b6igair3zf8gwllyzix97rlabxglif9f9qd9";
      type = "gem";
    };
    version = "2.1.2";
  };
  http-cookie = {
    dependencies = ["domain_name"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0cz2fdkngs3jc5w32a6xcl511hy03a7zdiy988jk1sf3bf5v3hdw";
      type = "gem";
    };
    version = "1.0.2";
  };
  mechanize = {
    dependencies = ["domain_name" "http-cookie" "mime-types" "net-http-digest_auth" "net-http-persistent" "nokogiri" "ntlm-http" "webrobots"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1lkdm8ag3kgx2xzrgqniljxs5famlm2h68cs2wr6l5x16dbx168p";
      type = "gem";
    };
    version = "2.7.4";
  };
  method_source = {
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1g5i4w0dmlhzd18dijlqw5gk27bv6dj2kziqzrzb7mpgxgsd1sf2";
      type = "gem";
    };
    version = "0.8.2";
  };
  mime-types = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "06lnv0w9j45llai5qhvc1m7w409j5lhnssdzkvv6yw49d632jxkz";
      type = "gem";
    };
    version = "2.99.2";
  };
  mini_magick = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1a59k5l29vj060yscaqk370rg5vyr132kbw6x3zar7khzjqjqd8p";
      type = "gem";
    };
    version = "4.5.1";
  };
  mini_portile2 = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1y25adxb1hgg1wb2rn20g3vl07qziq6fz364jc5694611zz863hb";
      type = "gem";
    };
    version = "2.1.0";
  };
  minitest = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1gfzf7112vffcwamfny06pz4wr16xdihz666m1s47v077560nrll";
      type = "gem";
    };
    version = "5.9.0";
  };
  net-http-digest_auth = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "14801gr34g0rmqz9pv4rkfa3crfdbyfk6r48vpg5a5407v0sixqi";
      type = "gem";
    };
    version = "1.4";
  };
  net-http-persistent = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1y9fhaax0d9kkslyiqi1zys6cvpaqx9a0y0cywp24rpygwh4s9r4";
      type = "gem";
    };
    version = "2.9.4";
  };
  nokogiri = {
    dependencies = ["mini_portile2" "pkg-config"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "17pjhvm4yigriizxbbpx266nnh6nckdm33m3j4ws9dcg99daz91p";
      type = "gem";
    };
    version = "1.6.8";
  };
  ntlm-http = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0yx01ffrw87wya1syivqzf8hz02axk7jdpw6aw221xwvib767d36";
      type = "gem";
    };
    version = "0.1.1";
  };
  open4 = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1cgls3f9dlrpil846q0w7h66vsc33jqn84nql4gcqkk221rh7px1";
      type = "gem";
    };
    version = "1.3.4";
  };
  parallel = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "17b8mp9rxa79m8fm8z28is0s3i2hpfacsq3aj5isfd1m1155lfwq";
      type = "gem";
    };
    version = "1.9.0";
  };
  pkg-config = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0lljiqnm0b4z6iy87lzapwrdfa6ps63x2z5zbs038iig8dqx2g0z";
      type = "gem";
    };
    version = "1.1.7";
  };
  pry = {
    dependencies = ["coderay" "method_source" "slop"];
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "05xbzyin63aj2prrv8fbq2d5df2mid93m81hz5bvf2v4hnzs42ar";
      type = "gem";
    };
    version = "0.10.4";
  };
  pry-byebug = {
    dependencies = ["byebug" "pry"];
    groups = ["test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0pvc94kgxd33p6iz41ghyadq8zfbjhkk07nvz2mbh3yhrc8w7gmw";
      type = "gem";
    };
    version = "3.4.0";
  };
  rake = {
    groups = ["test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "09kyh351gddn6gjz255hbaza1cw235xvfz9dc15rhyq9phvqdphc";
      type = "gem";
    };
    version = "0.9.6";
  };
  rubyzip = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "10a9p1m68lpn8pwqp972lv61140flvahm3g9yzbxzjks2z3qlb2s";
      type = "gem";
    };
    version = "1.2.0";
  };
  safe_yaml = {
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1hly915584hyi9q9vgd968x2nsi5yag9jyf5kq60lwzi5scr7094";
      type = "gem";
    };
    version = "1.0.4";
  };
  slop = {
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "00w8g3j7k7kl8ri2cf1m58ckxk8rn350gp4chfscmgv6pq1spk3n";
      type = "gem";
    };
    version = "3.6.0";
  };
  unf = {
    dependencies = ["unf_ext"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0bh2cf73i2ffh4fcpdn9ir4mhq8zi50ik0zqa1braahzadx536a9";
      type = "gem";
    };
    version = "0.1.4";
  };
  unf_ext = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "04d13bp6lyg695x94whjwsmzc2ms72d94vx861nx1y40k3817yp8";
      type = "gem";
    };
    version = "0.0.7.2";
  };
  vcr = {
    groups = ["test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1411v5nrcdmsaxlr3rgzw5lxpa6kpszq1rmm2k2ihgk119i624q4";
      type = "gem";
    };
    version = "2.9.3";
  };
  webmock = {
    dependencies = ["addressable" "crack" "hashdiff"];
    groups = ["test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "03vlr6axajz6c7xmlk0w1kvkxc92f8y2zp27wq1z6yk916ry25n5";
      type = "gem";
    };
    version = "1.24.6";
  };
  webrobots = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "19ndcbba8s8m62hhxxfwn83nax34rg2k5x066awa23wknhnamg7b";
      type = "gem";
    };
    version = "0.1.2";
  };
}
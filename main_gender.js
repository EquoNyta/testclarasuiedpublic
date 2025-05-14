// json path and sound parameters
const jsons_path = "src/jsons_en/";
const sp = {
  path: "mainTaskSounds/",
  path_alarm: "mainTaskSounds/alarms(CRM_RWC_Stage)/",
  path_noise: "mainTaskSounds/noiseMasker(Brungart(2001)_from_CRM)-44100Hz/",
  path_audiogram: "otherSounds/",
  freq_audiogram: [1000, 2000, 4000, 250, 500],
  freq_suffix: "Hz.wav",
  alarm_filename: [
    // "synth_M_IRBA_113_Hz_4000_ms_44100.wav", // bip for testing purpose only
    "synth_M_IRBA_107_Hz_500_ms_44100.wav",
    "synth_M_IRBA_110_Hz_500_ms_44100.wav",
    "synth_M_IRBA_113_Hz_500_ms_44100.wav",

    "synth_F_IRBA_217_Hz_500_ms_44100.wav",
    "synth_F_IRBA_220_Hz_500_ms_44100.wav",
    "synth_F_IRBA_223_Hz_500_ms_44100.wav",

    // "synth_M_IRBA_107_Hz_500_ms_44100_fmod_70_Hz_m_1_gainMoore.wav",
    // "synth_M_IRBA_110_Hz_500_ms_44100_fmod_70_Hz_m_1_gainMoore.wav",
    // "synth_M_IRBA_113_Hz_500_ms_44100_fmod_70_Hz_m_1_gainMoore.wav",

    // "synth_F_IRBA_217_Hz_500_ms_44100_fmod_70_Hz_m_1_gainMoore.wav",
    // "synth_F_IRBA_220_Hz_500_ms_44100_fmod_70_Hz_m_1_gainMoore.wav",
    // "synth_F_IRBA_223_Hz_500_ms_44100_fmod_70_Hz_m_1_gainMoore.wav",
  ],
  noise_filename: "noise_f.wav",
  speaker_male: [0, 1, 2, 3],
  speaker_female: [4, 5, 6, 7],
  callsign: [
    "Baron",
    "Arrow",
    "Charlie",
    "Eagle",
    "Hopper",
    "Laker",
    "Ringo",
    "Tiger",
  ],
  color: ["Blue", "Green", "Red", "White"],
  number: [1, 2, 3, 4, 5, 6, 7, 8],
};
const english_test_filename = "english_test";

// get the participant number
const subject_id = jsPsych.data.getURLVariable("PROLIFIC_PID");
const study_id = jsPsych.data.getURLVariable("STUDY_ID");
const session_id = jsPsych.data.getURLVariable("SESSION_ID");

const config_filename = _.shuffle(["f_vs_2m - Copie", "m_vs_2f - Copie"])[0];

const sameSex = false;
if (sameSex) {
  sp.alarm_filename = sp.alarm_filename.filter(
    (e) => e[e.indexOf("_") + 1].toLowerCase() === config_filename[0]
  );
} else {
  sp.alarm_filename = sp.alarm_filename.filter(
    (e) => e[e.indexOf("_") + 1].toLowerCase() !== config_filename[0]
  );
}

sp.alarm_filename = _.shuffle(sp.alarm_filename)[0];

console.log(config_filename);
console.log(sp.alarm_filename);

// load the configuration file
fetchAll({
  // main_task: 'tests/test3.json',
  main_task: jsons_path + config_filename + ".json",
  english_test: jsons_path + english_test_filename + ".json",
})
  .then((config) => {
    // first delete comment lines
    config = flatten(config, ".");
    Object.keys(config).map((e) => {
      if (/\._/gi.test(e)) {
        delete config[e];
      }
    });
    config = unflatten(config, ".");

    // the control part needs only one N condition so choose random one
    config.main_task.parameters.control_param.N = [
      config.main_task.parameters.N[
        getRandomIntInclusive(
          Math.min(...config.main_task.parameters.N),
          Math.max(...config.main_task.parameters.N)
        )
      ],
    ];

    // generate the timeline experiment
    let timeline = [];
    (function () {
      // let usePrompt = true;
      // let enable = usePrompt
      //   ? prompt("0 crm seulement, 1 : expérience complète", "0") == 1
      //     ? true
      //     : false
      //   : false;

      pavlovia_connect(timeline);
      // if (enable) {
      // consent(timeline);
      // informationNote(timeline);
      // headphoneCheck(timeline); // Etape 1/5
      // survey(timeline); // Etape 2/5
      // audiogram(
      //   sp.freq_audiogram,
      //   sp.freq_suffix,
      //   sp.path_audiogram,
      //   timeline
      // ); // Etape 3/5
      // task_gen( // comment also in processings !
      //   timeline,
      //   config.english_test.parameters,
      //   config.english_test.messages,
      //   sp
      // ); // Etape 4/5
      // }

      task_gen(
        timeline,
        config.main_task.parameters,
        config.main_task.messages,
        sp
      ); // Etape 5/5
      debrief(
        timeline,
        {
          for_finalDebrief: true,
        },
        {
          test_part: "endOfExperiment",
        }
      );
      pavlovia_disconnect(timeline, subject_id); // Save BEFORE display "the end"
      endOfExperiment(timeline);
    })(timeline);

    return timeline;
  })
  .then((timeline) => {
    // when its done, start the experiment
    let timer_exp = 0;
    jsPsych.init({
      timeline: timeline,
      show_progress_bar: true,
      message_progress_bar: "Progression",
      auto_update_progress_bar: false,
      exclusions: {
        audio: true,
      },
      on_trial_start: function () {
        timer_exp = performance.now();
      },
      on_trial_finish: function (data) {
        data.duration = performance.now() - timer_exp;
      },
      on_finish: function (data) {
        const sel = myfilter(data.values(), {
          trial_type: "debrief",
          test_part: "endOfExperiment",
        })[0].quickCheck;
        // console.log(sel.englishTest);
        // console.log(sel.experiment);
        // console.log(sel.control);
        // console.log(sel.control.alarm_presence);
        // console.log(sel.control.button_pressed_alarm);

        window.location.href =
          "https://app.prolific.co/submissions/complete?cc=6F195757";
      },
    });
  })
  .catch((err) => {
    console.error(err.message);
  });
